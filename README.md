# infra-lab

Lab DevOps hybride : Proxmox (local) + AWS (cloud), le tout en Infrastructure as Code.

## Structure

```
infra-lab/
├── terraform/
│   ├── aws/        # VPC, wg-gateway, monitoring, runner-ci
│   └── proxmox/    # VMs locales (k3s, infra)
├── ansible/        # configuration des VMs (roles, inventory)
├── k8s/            # manifests geres par ArgoCD (apps, argocd)
├── pipelines/      # CI/CD DevSecOps (Trivy, Semgrep, Gitleaks)
├── docs/           # schemas et notes par phase
└── README.md
```

## Phases

- [x] Phase 0 : Proxmox, reseau, template Ubuntu cloud-init
  - voir [docs/phase0-proxmox-template.md](docs/phase0-proxmox-template.md),
    [docs/phase0-proxmox-internal-network.md](docs/phase0-proxmox-internal-network.md),
    [docs/phase0-setup-aws-iam.md](docs/phase0-setup-aws-iam.md)
- [x] Phase 1 : Terraform + Ansible, VMs locales, WireGuard vers AWS, Traefik, DNS
  - [x] VMs AWS (wg-gateway, monitoring, runner-ci) via Terraform
  - [x] VMs Proxmox (k3s-master, k3s-worker, infra) via Terraform, IP fixes sur `vmbr1`
  - [x] Tunnel WireGuard entre Proxmox et AWS — voir [docs/phase1-wireguard-tunnel.md](docs/phase1-wireguard-tunnel.md)
  - [x] Traefik (HTTPS public, wg-gateway) + DNS interne (dnsmasq, Proxmox) — voir [docs/phase1-traefik-dns.md](docs/phase1-traefik-dns.md)
  - [ ] Ansible (pour l'instant tout est fait a la main, a automatiser)
- [x] Phase 2 : k3s + ArgoCD (GitOps) — voir [docs/phase2-k3s-argocd.md](docs/phase2-k3s-argocd.md)
- [ ] Phase 3 : pipeline DevSecOps (+ VM runner-ci)
- [ ] Phase 4 : monitoring sur AWS, alertes Telegram
