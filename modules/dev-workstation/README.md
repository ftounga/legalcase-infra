# Module `dev-workstation`

EC2 dev workstation pour reproduire en cloud le workflow local (Claude Code, multi-sessions, builds Maven/Angular, terraform apply, kubectl).

## Ce que provisionne le module

| Ressource | Détail |
|-----------|--------|
| EC2 instance | `m7i.2xlarge` par défaut (8 vCPU / 32 Go) — Ubuntu 24.04 LTS |
| Root EBS | 100 GiB gp3 chiffré, supprimé au terminate |
| Security Group | **Egress uniquement** — aucun port d'entrée, connexion via SSM |
| IAM instance role | `AmazonSSMManagedInstanceCore` + `AdministratorAccess` (parité avec le user IAM local) |
| Secrets Manager | Secret `legalcase-dev-workstation/github-credentials` — populé manuellement |
| EventBridge Scheduler | Auto-stop **22h00 Paris** chaque jour (DST gérée par AWS) |
| IMDSv2 | Forcé (token requis) |

## Connexion

Pas de SSH ouvert sur Internet — tout passe par **SSM Session Manager** :

```bash
aws ssm start-session \
  --target $(terraform output -raw instance_id) \
  --region eu-west-3 \
  --profile legalcase-terraform
```

Ou bien, après avoir installé le plugin SSM dans `~/.ssh/config` :

```
Host i-* mi-*
  ProxyCommand sh -c "aws ssm start-session --target %h --document-name AWS-StartSSHSession --parameters portNumber=%p --region eu-west-3 --profile legalcase-terraform"
  User ubuntu
```

→ `ssh i-0abc1234...` fonctionne, et avec lui `scp`, port-forwarding, etc.

## Cycle de vie

- Auto-stop **22h00 Paris** via EventBridge Scheduler (cron `0 22 * * ?`, timezone `Europe/Paris`)
- Démarrage manuel le matin :
  ```bash
  aws ec2 start-instances --instance-ids $(terraform output -raw instance_id) --profile legalcase-terraform
  ```
- Coût estimé (eu-west-3) : ~**60-80 $/mois** si éteinte chaque soir, ~**290 $/mois** en 24/7

## Bootstrap utilisateur

Le cloud-init installe : Java 21 (Temurin), Maven, Node 20, Docker, Terraform, AWS CLI v2, gh, kubectl, helm, **Claude Code CLI**.

Il configure ensuite :
- `git config user.name` et `user.email` (passés en variables)
- `gh auth login --with-token` à partir du PAT dans Secrets Manager
- `~/.aws/config` avec `credential_source = Ec2InstanceMetadata` → `aws` et `terraform` utilisent le rôle EC2 sans configuration de clés
- Clone des repos listés dans `repos_to_clone` dans `~/dev/`

Log complet sur l'instance : `/var/log/dev-bootstrap.log`. Le script est re-exécutable : `sudo bash /usr/local/bin/dev-bootstrap.sh`.

## Sécurité

- `AdministratorAccess` sur le rôle est volontaire (parité workflow local). À restreindre si la VM devient partagée.
- Aucun SSH ouvert — les sessions SSM sont auditées via CloudTrail.
- Le PAT GitHub vit uniquement dans Secrets Manager, jamais dans tfstate (le secret est créé vide par Terraform).
- Volume EBS chiffré (clé KMS par défaut AWS).
- IMDSv2 obligatoire.

## Inputs

| Variable | Défaut | Description |
|----------|--------|-------------|
| `project` | — | Préfixe des ressources |
| `environment` | — | Nom d'environnement (ex: `dev-workstation`) |
| `vpc_id` | — | VPC où lancer l'instance |
| `subnet_id` | — | Subnet privé avec egress NAT |
| `instance_type` | `m7i.2xlarge` | Type EC2 |
| `ebs_volume_size` | `100` | Taille root en GiB |
| `linux_user` | `ubuntu` | Utilisateur dev sur la VM |
| `git_user_name` | — | `git config user.name` |
| `git_user_email` | — | `git config user.email` |
| `repos_to_clone` | `[]` | URLs HTTPS à cloner dans `~/dev` |
| `aws_cli_profile` | `legalcase-terraform` | Nom du profil AWS CLI à créer |
| `auto_stop_cron` | `cron(0 22 * * ? *)` | Cron Paris d'auto-stop |

## Outputs

| Output | Description |
|--------|-------------|
| `instance_id` | ID EC2 |
| `private_ip` | IP privée |
| `github_secret_arn` | ARN du secret à populer une fois |
| `github_secret_id` | Nom du secret à populer une fois |
| `ssm_session_command` | Commande prête à coller pour ouvrir une session |
