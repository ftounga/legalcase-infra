# CLAUDE.md — legalcase-infra

## Contexte

Ce repo contient l'infrastructure AWS de LegalCase, provisionnée via Terraform.
Il est **séparé** du repo applicatif `legalCase` (Dockerfiles, K8s manifests, CI/CD).

## Documents de référence

- `docs/ARCHITECTURE_INFRA.md` — décisions d'architecture infra (à créer au fur et à mesure)
- Repo applicatif : `~/dev/legalCase`

---

## Stack technique

| Composant | Choix |
|-----------|-------|
| Cloud | AWS eu-west-3 (Paris) |
| Compute | EKS 1.31 — node group t3.medium |
| Base de données | RDS PostgreSQL 16 |
| Stockage | S3 AWS |
| Registry | ECR |
| Secrets | AWS Secrets Manager |
| IaC | Terraform >= 1.7 |
| State | S3 backend + DynamoDB lock |

---

## Règles impératives

### Sécurité
- **Aucune valeur sensible en dur** dans le code Terraform (clés, mots de passe, tokens)
- Tous les secrets dans AWS Secrets Manager
- Les credentials AWS viennent du profil local ou des variables d'env CI/CD — jamais commités
- S3 bucket documents : accès privé strict, pas de public access
- RDS : pas d'accès public, subnet privé uniquement

### Terraform
- Toujours travailler avec des **modules réutilisables** (`modules/`)
- Les environnements (`environments/staging`, `environments/production`) appellent les modules
- State Terraform dans S3 + verrou DynamoDB — jamais de state local commité
- `terraform fmt` avant tout commit
- `terraform validate` doit passer avant tout push
- Pas de `terraform apply` automatique — toujours manuel avec revue du plan

### Git
- Branches : `feat/infra-<sujet>` (ex: `feat/infra-eks`, `feat/infra-rds`)
- Un commit par ressource logique
- Ne jamais commiter `.terraform/`, `*.tfstate`, `*.tfstate.backup`, `**/.terraform.lock.hcl` (sauf lock file racine)

---

## Structure du repo

```
legalcase-infra/
├── CLAUDE.md
├── versions.tf          ← providers + versions requises
├── variables.tf         ← variables globales
├── outputs.tf           ← outputs globaux
├── modules/
│   ├── networking/      ← VPC, subnets, NAT Gateway, IGW
│   ├── eks/             ← cluster EKS + node group + IAM roles
│   ├── rds/             ← RDS PostgreSQL + subnet group + SG
│   ├── s3/              ← bucket documents + policy
│   └── ecr/             ← repositories ECR backend + frontend
├── environments/
│   ├── staging/
│   │   ├── main.tf      ← appel des modules
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── terraform.tfvars
│   └── production/
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       └── terraform.tfvars
└── docs/
    └── ARCHITECTURE_INFRA.md
```

---

## Commandes courantes

```bash
# Initialiser un environnement
cd environments/staging
terraform init

# Valider
terraform validate
terraform fmt -recursive

# Planifier
terraform plan -out=tfplan

# Appliquer (toujours après revue du plan)
terraform apply tfplan
```

---

## Environnements

| Env | Namespace K8s | RDS | Nœuds EKS |
|-----|--------------|-----|-----------|
| staging | staging | db.t3.micro | 1 nœud |
| production | production | db.t3.micro (Multi-AZ V2) | 2 nœuds |

---

## Séquence de travail

Pas de mini-spec formelle comme dans le repo applicatif, mais avant chaque modification :

1. **Décrire** ce qui va être créé/modifié
2. **Valider** avec `terraform validate` + `terraform plan`
3. **Commiter** avec un message clair
4. **Appliquer** manuellement après revue

---

## .gitignore obligatoire

```
.terraform/
*.tfstate
*.tfstate.backup
*.tfplan
.terraform.lock.hcl
*.auto.tfvars
```
