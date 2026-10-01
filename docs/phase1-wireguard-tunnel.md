# Phase 1 — Tunnel WireGuard Proxmox <-> AWS

## Architecture

```
AWS VPC (10.0.1.0/24)                          Proxmox local
┌─────────────────────────┐                    ┌──────────────────────────┐
│ monitoring   runner-ci  │                     │ k3s-master  k3s-worker   │
│ 10.0.1.x     10.0.1.x   │                     │ 10.10.10.10  10.10.10.11 │
│      \          /       │                     │       infra 10.10.10.12 │
│       \        /        │                     │            |            │
│    wg-gateway (routeur) │                     │        vmbr1 (Proxmox)  │
│    ens5: 10.0.1.92      │                     │        10.10.10.1       │
│    wg0:  10.8.0.1/24  <-┼--- tunnel WireGuard -┼->  wg0: 10.8.0.2/24     │
│    IP publique EIP      │    UDP 51820         │        (sur Proxmox)   │
└─────────────────────────┘                     └──────────────────────────┘
```

`wg-gateway` et `Proxmox` font tous les deux office de routeur pour leur
reseau local respectif. Chaque cote route l'autre reseau a travers le
tunnel grace a `AllowedIPs` (qui sert a la fois de cle de chiffrement et
de table de routage dans WireGuard).

## Configuration

### wg-gateway (AWS, `/etc/wireguard/wg0.conf`)

```ini
[Interface]
PrivateKey = <genere localement, jamais commite>
Address = 10.8.0.1/24
ListenPort = 51820
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -A FORWARD -o wg0 -j ACCEPT
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -D FORWARD -o wg0 -j ACCEPT

[Peer]
PublicKey = <cle publique Proxmox>
AllowedIPs = 10.8.0.2/32, 10.10.10.0/24
```

### Proxmox (local, `/etc/wireguard/wg0.conf`)

```ini
[Interface]
PrivateKey = <genere localement, jamais commite>
Address = 10.8.0.2/24
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -A FORWARD -o wg0 -j ACCEPT
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -D FORWARD -o wg0 -j ACCEPT

[Peer]
PublicKey = <cle publique wg-gateway>
Endpoint = <IP publique EIP wg-gateway>:51820
AllowedIPs = 10.8.0.1/32, 10.0.1.0/24
PersistentKeepalive = 25
```

`PersistentKeepalive` est necessaire cote Proxmox car il est derriere un
NAT (VMware, eventuellement CGNAT du FAI) — sans ca, le tunnel se
"ferme" cote AWS des que la table NAT locale expire.

Activation sur les deux machines :
```bash
systemctl enable --now wg-quick@wg0
```

## Cote Terraform (AWS)

- `aws_instance.wg_gateway` : `source_dest_check = false` (indispensable
  pour qu'elle puisse router du trafic qui ne lui est pas adresse)
- `aws_route.to_wireguard_net` et `aws_route.to_proxmox_net` : routes dans
  la route table publique vers `10.8.0.0/24` et `10.10.10.0/24`, cible =
  l'ENI de `wg-gateway`. Necessaire pour que `monitoring`/`runner-ci`
  (meme route table) sachent passer par `wg-gateway` pour joindre le lab
  local.
- Security group `wg-gateway-sg` : ingress `-1` (tous protocoles) depuis
  `10.0.1.0/24` — sans ca, le trafic ICMP/interne venant de
  `monitoring`/`runner-ci` est bloque en silence avant meme d'atteindre
  l'instance (le `tcpdump` sur son `ens5` ne montrait rien).
- Security group `infra-lab-internal-sg` : ingress `-1` depuis
  `10.8.0.0/24` **et** `10.10.10.0/24` (les reponses ICMP des VMs Proxmox
  sont sourcees en `10.10.10.x`, pas en `10.8.0.x` — une regle qui ne
  matchait que le premier bloquait les reponses).

## Pieges rencontres

| Symptome | Cause | Fix |
|---|---|---|
| SSH totalement bloque (`Connecting to...` sans suite) | CGNAT du FAI local : l'IP change entre deux requetes | Reessayer suffit en general ; sinon verifier l'IP reelle de connexion dans les logs `Last login from` |
| `wg show` : `0 B received` | Tunnel monte mais pas de handshake encore recu | Attendre quelques secondes, verifier `AllowedIPs`/`Endpoint` des deux cotes |
| Ping Proxmox <-> wg-gateway (`10.8.0.x`) OK mais rien derriere (`10.10.10.x` ou `10.0.1.x`) | `ip_forward=0` sur Proxmox malgre le `sysctl.conf` (pas vraiment applique) | `echo "net.ipv4.ip_forward=1" > /etc/sysctl.d/99-forward.conf && sysctl --system` |
| `tcpdump` cote AWS (`ens5`) ne montre rien du tout | Security group de `wg-gateway` sans regle pour le trafic transitant depuis le VPC | Ajouter ingress `-1` depuis `10.0.1.0/24` |
| Routes AWS (`10.8.0.0/24`/`10.10.10.0/24`) disparues apres un `apply` reussi | Modification manuelle dans la console AWS (suppression accidentelle en explorant) | `terraform plan`/`apply` pour reconcilier — **ne jamais modifier les routes/SG a la main dans la console**, toujours passer par Terraform |

## Verification

Depuis `monitoring` (AWS) :
```bash
ping -c 3 10.10.10.10   # k3s-master, via wg-gateway -> tunnel -> Proxmox
```

## A faire ensuite

- Traefik (point d'entree HTTPS sur `wg-gateway`, port 443 deja ouvert)
- DNS interne (VM `infra` ou dnsmasq existant sur Proxmox)
- Ansible pour automatiser l'installation WireGuard (actuellement fait a
  la main, pas encore reproductible en un clic)
