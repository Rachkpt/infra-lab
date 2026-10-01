# Phase 0 (partie AWS) — IAM, AWS CLI, nettoyage des VMs manuelles

## Contexte

Les VMs AWS (`wg-gateway`, `monitoring`, `runner-ci`) avaient été créées à la main depuis la console AWS pour tester. Elles doivent être recréées via Terraform pour rester en Infrastructure as Code.

## 1. Supprimer les VMs créées à la main

1. Console AWS → EC2 → Instances.
2. Sélectionner les 3 instances → **Instance state → Terminate instance**.
3. EC2 → Elastic IPs → **Release Elastic IP address** si une IP est allouée (sinon elle facture même inutilisée).
4. EC2 → Security Groups → supprimer ceux créés à la main (garder le `default`).
5. Vérifier qu'il ne reste aucune instance `running`.

## 2. Créer un utilisateur IAM dédié à Terraform

Ne jamais utiliser le compte root pour Terraform.

1. IAM → Users → Create user → nom `terraform-infra-lab`.
2. Créer un groupe `terraform-lab` avec les politiques :
   - `AmazonEC2FullAccess` (instances, Elastic IP, security groups, clés SSH)
   - `AmazonVPCFullAccess` (VPC, subnets, route tables, internet gateway)
3. Ne pas utiliser `AdministratorAccess` : si les clés fuitent, tout le compte est exposé. Si une autre policy manque plus tard (erreur `AccessDenied`), l'ajouter au groupe à ce moment-là.
4. Une fois l'utilisateur créé : onglet **Informations d'identification de sécurité → Créer une clé d'accès**, cas d'usage **Interface de ligne de commande (CLI)**.
5. Copier l'Access Key ID et la Secret Access Key (la clé secrète ne s'affiche qu'une seule fois).

## 3. Installer AWS CLI v2 (Ubuntu / WSL2)

Sur Ubuntu 24.04, `apt install awscli` n'existe plus. Installer la version officielle :

```bash
sudo apt update
sudo apt install -y unzip curl

curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

aws --version
```

(Si la machine est en ARM : remplacer `x86_64` par `aarch64` dans l'URL — vérifier avec `uname -m`.)

Nettoyer les fichiers d'installation :

```bash
rm -rf awscliv2.zip aws/
```

Sous Windows (PowerShell), alternative :

```powershell
winget install Amazon.AWSCLI
```

## 4. Configurer AWS CLI

```bash
aws configure
```

- Access Key ID : la clé copiée à l'étape 2
- Secret Access Key : la clé secrète
- Default region : `eu-west-3` (Paris) ou `eu-west-1` (Irlande)
- Default output format : `json`

Les clés sont stockées dans `~/.aws/credentials`, **jamais dans le repo Git**. Terraform les lira automatiquement.

Vérification :

```bash
aws sts get-caller-identity
```

Doit renvoyer un `Arn` qui se termine par `user/terraform-infra-lab`.

## 5. Sécurité — points à ne jamais oublier

- Ne jamais commiter de clé AWS (`*.csv`), de clé SSH (`*.pem`) ou de fichier `.env` — déjà couvert par le `.gitignore` du repo.
- Supprimer le fichier `.csv` des clés une fois `aws configure` fait.
- Activer le MFA sur le compte root AWS et ne plus s'en servir ensuite.
- Créer une alerte **AWS Budgets** (ex. 10 $) avant de créer la moindre VM.

## Prochaine étape

Écrire `terraform/aws/provider.tf` et recréer les 3 VMs (`wg-gateway`, `monitoring`, `runner-ci`) via Terraform.
