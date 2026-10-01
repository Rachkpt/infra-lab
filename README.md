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

- [ ] Phase 0 : Proxmox, reseau, template Ubuntu cloud-init
- [ ] Phase 1 : Terraform + Ansible, VMs locales, WireGuard vers AWS, Traefik, DNS
- [ ] Phase 2 : k3s + ArgoCD (GitOps)
- [ ] Phase 3 : pipeline DevSecOps (+ VM runner-ci)
- [ ] Phase 4 : monitoring sur AWS, alertes Telegram
