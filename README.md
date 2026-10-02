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
  - [x] Ansible — ecrit et valide, pas encore execute contre l'infra reelle, voir [docs/phase5-ansible.md](docs/phase5-ansible.md)
- [x] Phase 2 : k3s + ArgoCD (GitOps) — voir [docs/phase2-k3s-argocd.md](docs/phase2-k3s-argocd.md)
- [x] Phase 3 : pipeline DevSecOps (+ VM runner-ci) — voir [docs/phase3-devsecops-pipeline.md](docs/phase3-devsecops-pipeline.md)
- [x] Phase 4 : monitoring sur AWS, alertes Telegram — voir [docs/phase4-monitoring.md](docs/phase4-monitoring.md)
- [x] Phase 5 (bonus) : automatisation Ansible — voir [docs/phase5-ansible.md](docs/phase5-ansible.md) et [ansible/README.md](ansible/README.md)

## Statut

Les 5 phases prevues sont completes, plus le bonus Ansible (ecrit,
valide, a executer). Pistes restantes : lancer reellement
`ansible-playbook site.yml`, IP privees AWS stables, vrai nom de domaine
+ Let's Encrypt pour Traefik.
