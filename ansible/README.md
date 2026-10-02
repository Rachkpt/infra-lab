<p>
  <img src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/ansible.svg" width="40" title="Ansible" alt="Ansible"/>
</p>

# 🤖 Ansible — automatiser ce qu'on a fait à la main

Remplace toutes les commandes SSH manuelles des phases 0 à 4 par des
playbooks rejouables. Écrit et validé (`--syntax-check` + `ansible-lint`)
mais **pas encore exécuté contre l'infra réelle** — à lancer quand tu es
prêt.

## ✅ Prérequis (une seule fois)

1. **Installer Ansible** sur ta machine (celle qui a déjà les clés
   `terraform/aws/infra-lab-key.pem` et `terraform/proxmox/infra-lab-proxmox-key.pem`) :
   ```bash
   sudo apt install -y ansible
   ```

2. **Accès SSH à Proxmox lui-même** (pour la partie WireGuard côté
   local) : copie ta clé SSH publique habituelle dans
   `/root/.ssh/authorized_keys` sur Proxmox (Shell Proxmox) :
   ```bash
   mkdir -p /root/.ssh
   echo "TA_CLE_PUBLIQUE_ICI" >> /root/.ssh/authorized_keys
   ```
   (`cat ~/.ssh/id_ed25519.pub` ou équivalent sur ta machine pour la récupérer)

3. **Vérifier/mettre à jour `inventory/hosts.yml`** : les IP publiques
   AWS dynamiques (`monitoring`, `runner-ci`) et l'IP de Proxmox peuvent
   avoir changé depuis la rédaction de ce fichier — comparer avec
   `terraform output` dans `terraform/aws/` et `terraform/proxmox/`.

4. **Secrets** : copier et remplir le vault, puis le chiffrer avant de
   committer quoi que ce soit :
   ```bash
   cp group_vars/vault.yml.example group_vars/vault.yml
   nano group_vars/vault.yml   # token Telegram, chat ID, hash Traefik, PAT GitHub
   ansible-vault encrypt group_vars/vault.yml
   ```
   Le PAT GitHub a besoin de la permission **Administration: Read and
   write** sur le dépôt (pour que le rôle `github_runner` génère lui-même
   un token d'enregistrement de runner via l'API, sans passer par
   l'interface web à chaque fois).

## 🚀 Lancer

Tout d'un coup (demande le mot de passe du vault) :
```bash
cd ansible
ansible-playbook playbooks/site.yml --ask-vault-pass
```

Ou par morceaux, utile si une seule VM a été recréée (voir l'incident
documenté dans [docs/phase4-monitoring.md](../docs/phase4-monitoring.md)) :

| Playbook | Cible | Commande |
|---|---|---|
| 🔐 WireGuard | wg-gateway + Proxmox | `ansible-playbook playbooks/wireguard.yml --ask-vault-pass` |
| 🌐 Traefik | wg-gateway | `ansible-playbook playbooks/traefik.yml --ask-vault-pass` |
| ⎈ k3s | k3s-master + k3s-worker | `ansible-playbook playbooks/k3s.yml` |
| 📈 Observabilité | node_exporter + Promtail (5 VMs) | `ansible-playbook playbooks/observability.yml` |
| 📊 Stack monitoring | monitoring | `ansible-playbook playbooks/monitoring_stack.yml --ask-vault-pass` |
| 🤖 Runner CI | runner-ci | `ansible-playbook playbooks/runner.yml --ask-vault-pass` |

## 🗂️ Organisation

- `inventory/hosts.yml` — groupes `aws`, `proxmox_vms`, `proxmox_host`,
  `k3s_masters`, `k3s_workers`, `monitored` (tous ceux qui reçoivent
  node_exporter + Promtail).
- `group_vars/all.yml` — versions des outils, paramètres WireGuard
  (non-secrets).
- `group_vars/vault.yml` — secrets, chiffré via `ansible-vault` (jamais
  commité en clair, voir `.gitignore`).
- `roles/` — un rôle par responsabilité (voir
  [docs/phase5-ansible.md](../docs/phase5-ansible.md) pour le détail de
  chacun).
- `playbooks/` — un playbook par rôle appliqué à son/ses hôte(s), plus
  `site.yml` qui rejoue tout dans l'ordre de dépendance.

## ⚠️ Points d'attention

- Le rôle `wireguard` doit tourner sur **wg-gateway et proxmox dans la
  même invocation** (chaque côté a besoin de la clé publique de l'autre,
  échangée via `hostvars` — pas de cache de facts configuré).
- Idem pour `k3s_server` (k3s-master) avant `k3s_agent` (k3s-worker) :
  le token de jonction est lu depuis `hostvars['k3s-master']`.
- Rien n'est idempotent à 100% au sens strict pour les installations
  binaires (vérification par `stat` avant téléchargement), mais rejouer
  un playbook sur une VM déjà configurée ne doit rien casser.
