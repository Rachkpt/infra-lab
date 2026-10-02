# Ansible — automatisation de ce qu'on a fait a la main

Remplace toutes les commandes SSH manuelles des phases 0 a 4 par des
playbooks rejouables. Ecrit et valide (`--syntax-check` + `ansible-lint`)
mais **pas encore execute contre l'infra reelle** — a lancer quand tu es
pret.

## Prerequis (une seule fois)

1. **Installer Ansible** sur ta machine (celle qui a deja les cles
   `terraform/aws/infra-lab-key.pem` et `terraform/proxmox/infra-lab-proxmox-key.pem`) :
   ```bash
   sudo apt install -y ansible
   ```

2. **Acces SSH a Proxmox lui-meme** (pour la partie WireGuard cote
   local) : copie ta cle SSH publique habituelle dans
   `/root/.ssh/authorized_keys` sur Proxmox (Shell Proxmox) :
   ```bash
   mkdir -p /root/.ssh
   echo "TA_CLE_PUBLIQUE_ICI" >> /root/.ssh/authorized_keys
   ```
   (`cat ~/.ssh/id_ed25519.pub` ou equivalent sur ta machine pour la recuperer)

3. **Verifier/mettre a jour `inventory/hosts.yml`** : les IP publiques
   AWS dynamiques (`monitoring`, `runner-ci`) et l'IP de Proxmox peuvent
   avoir change depuis la redaction de ce fichier — comparer avec
   `terraform output` dans `terraform/aws/` et `terraform/proxmox/`.

4. **Secrets** : copier et remplir le vault, puis le chiffrer avant de
   committer quoi que ce soit :
   ```bash
   cp group_vars/vault.yml.example group_vars/vault.yml
   nano group_vars/vault.yml   # token Telegram, chat ID, hash Traefik, PAT GitHub
   ansible-vault encrypt group_vars/vault.yml
   ```
   Le PAT GitHub a besoin de la permission **Administration: Read and
   write** sur le depot (pour que le role `github_runner` genere lui-meme
   un token d'enregistrement de runner via l'API, sans passer par
   l'interface web a chaque fois).

## Lancer

Tout d'un coup (demande le mot de passe du vault) :
```bash
cd ansible
ansible-playbook playbooks/site.yml --ask-vault-pass
```

Ou par morceaux, utile si une seule VM a ete recreee (voir l'incident
documente dans [docs/phase4-monitoring.md](../docs/phase4-monitoring.md)) :
```bash
ansible-playbook playbooks/wireguard.yml --ask-vault-pass        # wg-gateway + Proxmox
ansible-playbook playbooks/traefik.yml --ask-vault-pass          # wg-gateway
ansible-playbook playbooks/k3s.yml                               # k3s-master + k3s-worker
ansible-playbook playbooks/observability.yml                     # node_exporter + Promtail, les 5 VMs
ansible-playbook playbooks/monitoring_stack.yml --ask-vault-pass # monitoring
ansible-playbook playbooks/runner.yml --ask-vault-pass           # runner-ci
```

## Organisation

- `inventory/hosts.yml` — groupes `aws`, `proxmox_vms`, `proxmox_host`,
  `k3s_masters`, `k3s_workers`, `monitored` (tous ceux qui recoivent
  node_exporter + Promtail).
- `group_vars/all.yml` — versions des outils, parametres WireGuard
  (non-secrets).
- `group_vars/vault.yml` — secrets, chiffre via `ansible-vault` (jamais
  committe en clair, voir `.gitignore`).
- `roles/` — un role par responsabilite (voir
  [docs/phase5-ansible.md](../docs/phase5-ansible.md) pour le detail de
  chacun).
- `playbooks/` — un playbook par role applique a son/ses hote(s), plus
  `site.yml` qui rejoue tout dans l'ordre de dependance.

## Points d'attention

- Le role `wireguard` doit tourner sur **wg-gateway et proxmox dans la
  meme invocation** (chaque cote a besoin de la cle publique de l'autre,
  echangee via `hostvars` — pas de cache de facts configure).
- Idem pour `k3s_server` (k3s-master) avant `k3s_agent` (k3s-worker) :
  le token de jonction est lu depuis `hostvars['k3s-master']`.
- Rien n'est idempotent a 100% au sens strict pour les installations
  binaires (verification par `stat` avant telechargement), mais rejouer
  un playbook sur une VM deja configuree ne doit rien casser.
