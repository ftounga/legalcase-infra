# Environnement `dev-workstation`

Provisionne **une** EC2 dev workstation dans le VPC `cluster` partagé.

Voir aussi : [`modules/dev-workstation/README.md`](../../modules/dev-workstation/README.md)

---

## Première mise en place (one-shot)

### 1. Apply Terraform

```bash
cd environments/dev-workstation
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

Récupérer les outputs :

```bash
terraform output
# instance_id          = "i-0abc..."
# github_secret_id     = "legalcase-dev-workstation/github-credentials"
# ssm_session_command  = "aws ssm start-session --target i-0abc... ..."
```

### 2. Populer le PAT GitHub dans Secrets Manager

Créer un PAT GitHub avec les scopes `repo` + `workflow` + `read:org` sur https://github.com/settings/tokens (token classique, durée d'expiration au choix).

> Le scope `read:org` est requis par `gh auth login --with-token`. Sans lui, git clone/push fonctionnent quand même (via le credential helper), mais le CLI `gh` reste non-authentifié — il faudra lancer `gh auth login` interactivement.

Puis :

```bash
aws secretsmanager put-secret-value \
  --secret-id legalcase-dev-workstation/github-credentials \
  --secret-string '{"github_token":"ghp_xxx","github_user":"ftounga"}' \
  --region eu-west-3 \
  --profile legalcase-terraform
```

### 3. Re-déclencher le bootstrap (si le secret a été populé après l'apply)

Si le secret était vide au premier boot, cloud-init aura terminé sans configurer git/gh. Se connecter et relancer :

```bash
aws ssm start-session \
  --target $(terraform output -raw instance_id) \
  --region eu-west-3 \
  --profile legalcase-terraform

# Dans la session :
sudo bash /usr/local/bin/dev-bootstrap.sh
exit
```

### 4. Vérifier l'installation

Toujours dans la session SSM :

```bash
java --version          # Temurin 21
node --version          # v20.x
mvn --version
terraform version       # >= 1.3
gh auth status          # logged in
docker ps               # OK (relancer la session après ajout au groupe docker)
claude --version        # Claude Code CLI

ls ~/dev/               # legalCase  legalcase-infra
```

### 5. Authentifier Claude Code (interactif, une seule fois)

Claude Code n'est pas pré-authentifié — il utilise OAuth via ton compte Anthropic/Claude.ai.

```bash
claude login
```

Le CLI affiche un code à coller dans ton browser local (device flow). Une fois validé, les credentials sont persistées dans `~/.config/claude-code/` sur la VM et survivent aux redémarrages.

---

## Usage quotidien

### Démarrer la VM le matin

```bash
aws ec2 start-instances \
  --instance-ids $(cd environments/dev-workstation && terraform output -raw instance_id) \
  --profile legalcase-terraform
```

Ou créer un alias dans `~/.bashrc` :

```bash
alias devbox-start='aws ec2 start-instances --instance-ids i-XXXX --profile legalcase-terraform --region eu-west-3'
alias devbox-stop='aws ec2 stop-instances --instance-ids i-XXXX --profile legalcase-terraform --region eu-west-3'
alias devbox-ssh='aws ssm start-session --target i-XXXX --profile legalcase-terraform --region eu-west-3'
```

L'auto-stop **22h00 Paris** se charge du soir si tu oublies.

### Lancer plusieurs sessions Claude en parallèle

Dans la VM, utiliser `tmux` ou plusieurs sessions SSM simultanées :

```bash
tmux new -s claude-1
# dans la session : cd ~/dev/legalCase && claude
# Ctrl+B D pour détacher

tmux new -s claude-2
# autre feature
```

---

## Coûts

| Mode | Coût mensuel estimé |
|------|---------------------|
| Éteinte chaque soir (22h-8h, 7j/7) | ~60-80 $/mois (compute) + ~10 $/mois (EBS 100 Go gp3) |
| 24/7 | ~290 $/mois (compute) + ~10 $/mois (EBS) |

EBS persiste même quand l'instance est `Stopped` (~0,10 $/Go/mois).

---

## Destruction

```bash
cd environments/dev-workstation
terraform destroy
```

Détruit l'instance, le SG, l'IAM role, le secret Secrets Manager (recovery_window_in_days = 0). Le state Terraform reste dans S3.
