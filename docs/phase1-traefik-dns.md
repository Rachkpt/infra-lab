# Phase 1 — Traefik (entree publique) et DNS interne

## DNS interne (Proxmox, dnsmasq)

Le `dnsmasq` deja en place pour le DHCP de `vmbr1` (voir
[phase0-proxmox-internal-network.md](phase0-proxmox-internal-network.md))
sert aussi de resolveur DNS pour les VMs locales. Enregistrements statiques
ajoutes dans `/etc/dnsmasq.d/lab-dns.conf` :

```
address=/k3s-master.lab/10.10.10.10
address=/k3s-worker.lab/10.10.10.11
address=/infra.lab/10.10.10.12
```

Les VMs utilisent deja `10.10.10.1` comme serveur DNS (configure via
Terraform dans `terraform/proxmox/main.tf`, bloc `initialization.dns`),
donc la resolution est immediate apres `systemctl restart dnsmasq`.

Verification :
```bash
getent hosts k3s-master.lab
```

## Traefik (wg-gateway, AWS)

Installe en binaire statique (pas de Docker, pour rester leger sur un
`t3.micro` 1 Go de RAM) :

```bash
curl -L https://github.com/traefik/traefik/releases/download/v3.1.6/traefik_v3.1.6_linux_amd64.tar.gz -o /tmp/traefik.tar.gz
cd /tmp && tar xzf traefik.tar.gz traefik
sudo mv traefik /usr/local/bin/ && sudo chmod +x /usr/local/bin/traefik
```

Config statique `/etc/traefik/traefik.yml` : entrypoint `websecure` (443),
dashboard active, provider `file` pour la config dynamique.

Config dynamique `/etc/traefik/dynamic.yml` : route le dashboard
(`/dashboard`, `/api`) derriere une authentification basique
(`htpasswd -nb admin <password>` pour generer le hash, jamais le mot de
passe en clair dans les fichiers commites).

Pas de nom de domaine pour l'instant -> pas d'ACME/Let's Encrypt
configure. Traefik genere automatiquement un certificat auto-signe
("TRAEFIK DEFAULT CERT") pour l'entrypoint `websecure`, donc HTTPS
fonctionne deja (avec avertissement navigateur, normal sans domaine).

Service systemd `/etc/systemd/system/traefik.service`, active avec
`systemctl enable --now traefik`.

Verification :
```bash
curl -k -u admin:<password> https://<EIP-wg-gateway>/api/overview
```

## Prochaine etape (quand il y aura un vrai domaine)

Remplacer le certificat auto-signe par Let's Encrypt : ajouter un bloc
`certificatesResolvers` dans `traefik.yml` (resolver `acme` type HTTP-01
ou DNS-01 selon le registrar), pointer le domaine vers l'Elastic IP, et
ajouter `tls.certResolver: acme` sur les routers concernes. Aucun autre
changement d'architecture necessaire.

## Pour la Phase 2 (k3s)

Une fois le cluster k3s deploye, Traefik sur `wg-gateway` devra proxyer
vers les services internes (via le tunnel WireGuard, a travers
`10.10.10.0/24`). Deux options a trancher a ce moment-la :
- ajouter des routers File Provider statiques pointant vers les IP/ports
  des services k3s (simple mais manuel) ;
- ou deployer un second Traefik/ingress directement dans k3s et faire de
  celui de `wg-gateway` un simple relais TCP (passthrough) vers lui.
