# Phase 0 — Reseau interne Proxmox (vmbr1) pour les VMs k3s/infra

## Pourquoi

En virtualisation imbriquee (VMware -> Proxmox -> VMs), le DHCP du reseau NAT
de VMware ne repond pas aux requetes DHCP des VMs qui tournent *derriere*
le bridge de Proxmox (`vmbr0`). Confirme avec `tcpdump -i vmbr0 port 67 or 68` :
les `DHCP Request` sortent bien des VMs et arrivent sur `vmbr0`, mais aucune
reponse ne revient jamais — le NAT de VMware ignore les adresses MAC qu'il
ne connait pas.

Solution : un bridge interne (`vmbr1`) propre a Proxmox, avec son propre
serveur DHCP (`dnsmasq`) et du NAT (masquerade) vers l'exterieur via `vmbr0`.
Proxmox devient le routeur de ce reseau — ce qui correspond de toute facon
a l'architecture prevue pour la Phase 1 (WireGuard).

## Mise en place (Shell Proxmox, en root)

### 1. Creer le bridge interne

Editer `/etc/network/interfaces` et ajouter a la fin :

```
auto vmbr1
iface vmbr1 inet static
        address 10.10.10.1/24
        bridge-ports none
        bridge-stp off
        bridge-fd 0
        post-up   iptables -t nat -A POSTROUTING -s '10.10.10.0/24' -o vmbr0 -j MASQUERADE
        post-down iptables -t nat -D POSTROUTING -s '10.10.10.0/24' -o vmbr0 -j MASQUERADE
```

Appliquer sans reboot :

```bash
ifreload -a
ip addr show vmbr1
```

### 2. Activer le routage IP (forwarding)

```bash
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl -p
```

### 3. Installer et configurer dnsmasq (DHCP pour vmbr1)

```bash
apt update
apt install -y dnsmasq
```

Creer `/etc/dnsmasq.d/vmbr1.conf` :

```
interface=vmbr1
bind-interfaces
dhcp-range=10.10.10.50,10.10.10.100,12h
dhcp-option=3,10.10.10.1
dhcp-option=6,1.1.1.1,8.8.8.8
```

Plage DHCP volontairement a partir de `.50` : les 3 VMs d'infra
(`k3s-master`, `k3s-worker`, `infra`) ont des IP fixes (`.10`, `.11`, `.12`)
configurees directement par Terraform, pour un control-plane stable. Le
DHCP ne sert qu'aux futures VMs ajoutees manuellement sur ce reseau.

```bash
systemctl restart dnsmasq
systemctl enable dnsmasq
```

### 4. Verifier qu'il n'y a pas de conflit sur le port 53

```bash
ss -tulpn | grep :53
```

`dnsmasq` doit apparaitre lie uniquement a `10.10.10.1:53` (grace a
`bind-interfaces`), pas en conflit avec `systemd-resolved` qui ecoute sur
`127.0.0.53` et l'IP de `vmbr0`.

## Cote Terraform

Les 3 VMs (`k3s-master`, `k3s-worker`, `infra`) sont rattachees a `vmbr1`
au lieu de `vmbr0` (bloc `network_device { bridge = "vmbr1" }` dans
`terraform/proxmox/main.tf`). Elles recoivent leur IP via le DHCP de
`dnsmasq` (plage `10.10.10.10-100`), passent par Proxmox pour sortir sur
internet (masquerade), et restent injoignables depuis l'exterieur sans
passer par Proxmox — ce qui est voulu pour un lab isole.

## A ajuster en Phase 1

Le security group AWS `internal_only` autorise deja le CIDR `10.8.0.0/24`
pour le futur tunnel WireGuard — a verifier/ajuster une fois le tunnel en
place pour que les flux Proxmox (`10.10.10.0/24`) <-> AWS fonctionnent
correctement (routage cote WireGuard + regles de securite des deux cotes).
