# Phase 5 (bonus) — Automatiser avec Ansible

Tout ce qui avait ete fait a la main par SSH entre les Phases 0 et 4 est
desormais rejouable via Ansible. Ecrit, verifie (`--syntax-check` +
`ansible-lint`, profil "basic") mais **non execute contre l'infra
reelle** — voir [ansible/README.md](../ansible/README.md) pour les
prerequis et le lancement.

## Pourquoi maintenant

L'incident de la Phase 4 (les 3 VMs AWS recreees d'un coup, voir
[phase4-monitoring.md](phase4-monitoring.md)) a couté une bonne heure de
reinstallation manuelle — WireGuard, Traefik, le runner GitHub Actions,
les 3 scanners, toute la stack Docker. Avec Ansible, la meme situation se
regle en relancant un ou deux playbooks.

## Correspondance commandes manuelles -> roles

| Fait a la main (Phases 0-4) | Role Ansible |
|---|---|
| Installation WireGuard + generation de cles + `wg0.conf` (wg-gateway et Proxmox) | `wireguard` |
| Installation Traefik + config statique/dynamique + service systemd | `traefik` |
| `node_exporter` sur les 5 VMs | `node_exporter` |
| Promtail (logs -> Loki) sur les 5 VMs | `promtail` |
| `curl get.k3s.io` sur k3s-master | `k3s_server` |
| `curl get.k3s.io` avec `K3S_URL`/`K3S_TOKEN` sur k3s-worker | `k3s_agent` |
| `apt install docker.io` + groupe docker | `docker` |
| `git clone` + `alertmanager.yml` + `docker compose up` | `monitoring_stack` |
| Enregistrement runner GitHub Actions (token UI + `config.sh`) | `github_runner` |
| Gitleaks, Semgrep (pipx), Trivy | `security_scanners` |

## Ecarts volontaires par rapport au manuel

- **Token de runner GitHub genere via l'API**, pas copie-colle depuis
  l'UI (qui expire en ~1h et n'est utilisable qu'une fois — incompatible
  avec un playbook rejouable). Necessite un PAT avec la permission
  `Administration: Read and write` sur le depot, stocke chiffre dans
  `group_vars/vault.yml`.
- **Secrets jamais en clair dans le depot** : token Telegram, hash
  Traefik, PAT GitHub passent par `ansible-vault` (`group_vars/vault.yml`
  chiffre, le `.example` reste en clair comme gabarit).
- **Cles WireGuard generees sur la cible elle-meme**, jamais stockees
  dans le depot ni dans le vault — exactement comme fait a la main.
  Chaque cote expose sa cle publique en fact Ansible (`hostvars`), lu par
  l'autre cote dans le meme run.
- **k3s_server et k3s_agent** fonctionnent sur le meme principe :
  `k3s_server` expose le node-token en fact, `k3s_agent` le lit via
  `hostvars['k3s-master']`. Obligatoire d'avoir les deux dans la meme
  invocation de playbook (`playbooks/k3s.yml` les enchaine dans l'ordre).

## Limite connue : IP AWS dynamiques

`inventory/hosts.yml` contient les IP publiques de `monitoring` et
`runner-ci` en dur — elles changent a chaque remplacement d'instance
(meme souci que documente en Phase 4). Pas encore automatise ; a
corriger plus tard soit avec des `private_ip` explicites dans Terraform
(qui eviterait le probleme a la racine), soit avec un inventaire
dynamique genere depuis `terraform output`.

## Verification faite (sans toucher a l'infra)

```bash
ansible-playbook playbooks/<nom>.yml --syntax-check   # 7/7 playbooks OK
ansible-lint playbooks/site.yml                       # 0 erreur bloquante,
                                                        # 13 nitpicks cosmetiques
                                                        # (prefixe de nom de variable,
                                                        # une URL un peu longue)
```

## A faire au premier lancement reel

1. Suivre les prerequis de [ansible/README.md](../ansible/README.md)
   (cle SSH sur Proxmox, vault chiffre, IP a jour dans l'inventaire).
2. Lancer `playbooks/site.yml` une premiere fois en acceptant de
   regarder chaque etape (`--step` ou playbook par playbook plutot que
   tout d'un coup).
3. Comparer le resultat avec l'etat actuel reel (VMs deja configurees a
   la main) — s'attendre a ce que la plupart des taches remontent
   `ok` (deja fait) plutot que `changed`, sauf pour les VMs AWS
   recemment recreees qui, elles, repartiront de zero.
