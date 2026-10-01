# Phase 3 — Pipeline DevSecOps (runner-ci, Gitleaks, Semgrep, Trivy)

## VM `runner-ci` (AWS)

Runner GitHub Actions auto-heberge, installe a la main (pas encore
Ansible) :

```bash
mkdir actions-runner && cd actions-runner
curl -o actions-runner-linux-x64-2.337.0.tar.gz -L https://github.com/actions/runner/releases/download/v2.337.0/actions-runner-linux-x64-2.337.0.tar.gz
tar xzf ./actions-runner-linux-x64-2.337.0.tar.gz
./config.sh --url https://github.com/Rachkpt/infra-lab --token <TOKEN_DEPUIS_GITHUB_UI>
sudo ./svc.sh install
sudo ./svc.sh start
```

Le token d'enregistrement se recupere sur
`Settings > Actions > Runners > New self-hosted runner` du depot GitHub —
il expire au bout d'environ une heure et n'est utilisable qu'une fois.

## Outils installes sur `runner-ci`

```bash
# Gitleaks (scan de secrets)
curl -sSL https://github.com/gitleaks/gitleaks/releases/download/v8.21.2/gitleaks_8.21.2_linux_x64.tar.gz -o /tmp/gitleaks.tar.gz
sudo tar xzf /tmp/gitleaks.tar.gz -C /usr/local/bin gitleaks

# Semgrep (analyse statique) — via pipx, pip3 seul entre en conflit
# avec des paquets geres par apt sur Ubuntu 24.04
sudo apt-get install -y pipx
pipx install semgrep
sudo ln -s ~/.local/bin/semgrep /usr/local/bin/semgrep

# Trivy (secrets + misconfigurations IaC)
sudo apt-get install -y wget apt-transport-https gnupg lsb-release
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo gpg --dearmor -o /usr/share/keyrings/trivy.gpg
echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" | sudo tee -a /etc/apt/sources.list.d/trivy.list
sudo apt-get update && sudo apt-get install -y trivy
```

## Le pipeline

[`.github/workflows/devsecops.yml`](../.github/workflows/devsecops.yml) :
declenche sur push/PR vers `main`, tourne sur le runner self-hosted
(`runs-on: self-hosted`).

Trois etapes :
1. **Gitleaks** — scan de tout l'historique Git (`fetch-depth: 0`) a la
   recherche de secrets commites (cles, tokens...).
2. **Semgrep** — analyse statique (`--config auto`, detecte le langage
   automatiquement — ici surtout Terraform/YAML).
3. **Trivy** — secrets (double verification) + mauvaises configurations
   IaC (Terraform, Kubernetes), severite `HIGH`/`CRITICAL` uniquement
   pour ne pas noyer le signal.

Chaque etape fait echouer le job (`exit-code 1` / `--error`) si elle
trouve quelque chose — c'est un vrai gate, pas juste un rapport
informatif.

## Premier run : les vrais findings et comment on les a traites

Le tout premier run a casse a 3 reprises pour des raisons differentes,
plutot instructif sur le fonctionnement reel de ces outils :

1. **Semgrep refuse `--config auto` avec `--metrics=off`** — ce mode a
   besoin du registre Semgrep (donc des metriques actives) pour choisir
   les regles automatiquement. Retire `--metrics=off`.

2. **Semgrep a trouve 4 vrais problemes** des le premier scan :
   - `actions/checkout@v4` (tag mutable, risque supply-chain) -> epingle
     sur un SHA de commit : `actions/checkout@8ade135a...`
   - `hello-world` sans `securityContext` -> ajout de
     `allowPrivilegeEscalation: false` (vrai fix) et
     `readOnlyRootFilesystem: true` + volumes `emptyDir` pour les
     chemins ecrits par nginx (`/tmp`, `/var/cache/nginx`, `/var/run`)
   - `aws_subnet.public` avec IP publique -> choix assume du lab (pas de
     NAT Gateway payante), documente et suppresse plutot que "corrige"

3. **Trivy a son propre moteur de regles**, independant de Semgrep : IMDSv2
   non force (`AWS-0028`), disques racine non chiffres (`AWS-0131`),
   egress large sur les security groups (`AWS-0104`), meme finding IP
   publique mais sous un ID different (`AWS-0164`), et le meme "root
   necessaire pour nginx" sous l'ID `KSV-0118`. Les deux premiers sont
   de vrais fixes faciles (ajoutes dans `main.tf` : `metadata_options`
   et `root_block_device.encrypted`) ; le reste est le meme type de
   compromis assume que pour Semgrep.

### Suppression de findings : la syntaxe compte, et elle differe par type de fichier

- **Terraform (HCL)** : `# nosemgrep: <regle>` et `# trivy:ignore:<ID>`
  fonctionnent tous les deux, mais doivent etre sur la **premiere ligne
  du bloc matche** (`resource "..." "..." {  # nosemgrep: ... trivy:ignore:...`),
  pas sur l'attribut en cause ni sur une ligne a part — sinon l'outil
  l'ignore silencieusement et continue a remonter le finding. Attention
  aussi a l'ID exact : Semgrep l'affiche en double dans ses logs
  (`terraform.aws.security.X.X`), c'est bien l'ID complet a reprendre.
- **Kubernetes (YAML)** : `# nosemgrep: <regle>` fonctionne en trailing
  comment sur la ligne `spec:` du pod. Le `# trivy:ignore:<ID>` en
  revanche **ne fonctionne pas du tout** sur ces manifests (contrairement
  au Terraform) — il faut passer par un fichier `.trivyignore` a la
  racine du depot (un ID par ligne).

## Pourquoi pas dans `pipelines/`

Le dossier `pipelines/` prevu dans la structure initiale du depot ne
peut pas etre utilise directement : GitHub Actions n'execute que les
workflows places sous `.github/workflows/`. `pipelines/README.md`
pointe vers le vrai fichier.

## Limites actuelles

- Runner self-hosted sur un depot **public** : GitHub deconseille ca
  (une PR malveillante pourrait executer du code sur `runner-ci`). Pas
  critique pour un lab perso, mais a garder en tete — si le depot doit
  rester public durablement, il faudra soit le repasser en prive, soit
  restreindre les workflows aux push directs sur `main` (pas de PR
  externes).
- Pas encore de notification (Slack/Telegram) en cas d'echec — prevu en
  Phase 4 avec Alertmanager/Telegram, pourrait aussi couvrir ce pipeline.
