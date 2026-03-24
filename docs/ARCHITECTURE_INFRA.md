# Architecture Infrastructure — LegalCase

## Vue d'ensemble

L'infrastructure LegalCase est provisionnée via Terraform sur AWS eu-west-3 (Paris).
Deux environnements indépendants : **staging** et **production**, chacun avec son propre VPC.

## Décisions d'architecture

### ADR-001 : VPC séparés par environnement

**Décision :** Un VPC par environnement (staging et production).

**Raison :** Isolation réseau stricte, pas de risque de cross-contamination entre environnements.

**Conséquences :**
- Coûts NAT Gateway doublés (un par VPC)
- Isolation complète du trafic réseau

### ADR-002 : Cluster EKS unique par environnement

**Décision :** Un cluster EKS par environnement, avec namespaces Kubernetes pour séparer les applications.

**Raison :** Isolation des ressources de calcul, policies IAM et RBAC plus simples.

**Conséquences :**
- Staging : 1 nœud t3.medium (min 1 / max 2)
- Production : 2 nœuds t3.medium (min 2 / max 4)

### ADR-003 : RDS PostgreSQL 16 en subnet privé

**Décision :** RDS déployé uniquement dans des subnets privés, sans accès public.

**Raison :** Conformité sécurité, accès uniquement depuis les nœuds EKS.

**Conséquences :**
- Staging : db.t3.micro, single-AZ
- Production : db.t3.micro, Multi-AZ (standby automatique)

### ADR-004 : Secrets dans AWS Secrets Manager

**Décision :** Tous les secrets (mots de passe RDS) stockés dans AWS Secrets Manager.

**Raison :** Aucune valeur sensible en clair dans Terraform ou le code applicatif.

**Conséquences :**
- Password RDS généré aléatoirement par Terraform (`random_password`)
- Accessible depuis les pods via IRSA ou injection de variables via External Secrets Operator

### ADR-005 : State Terraform dans S3 + DynamoDB

**Décision :** State Terraform dans un bucket S3 dédié avec verrou DynamoDB.

**Raison :** Collaboration multi-développeur, protection contre les apply concurrents.

**Conséquences :**
- Bucket : `legalcase-terraform-state-504895205419`
- Table DynamoDB : `legalcase-terraform-lock`
- Bootstrap manuel (voir `bootstrap/`) avant le premier `terraform init`

### ADR-006 : ECR partagé entre environnements

**Décision :** Un seul set de repositories ECR (pas de duplication par env).

**Raison :** Les images Docker sont les mêmes, seul le tag change (staging-* vs prod-*).

**Conséquences :**
- `legalcase-backend` et `legalcase-frontend` dans ECR
- Lifecycle policies pour nettoyer automatiquement les anciennes images

## Architecture réseau

```
                          ┌─────────────────────────────────────────┐
                          │  VPC staging 10.0.0.0/16                │
                          │                                          │
                          │  ┌─────────────┐  ┌─────────────────┐  │
Internet ─── IGW ────────►│  │Public Subnets│  │ Private Subnets │  │
                          │  │ 10.0.1-3/24 │  │  10.0.10-12/24  │  │
                          │  │  (NAT GW)   │  │  (EKS Nodes)    │  │
                          │  └─────────────┘  └─────────────────┘  │
                          │                   ┌─────────────────┐   │
                          │                   │  DB Subnets     │   │
                          │                   │ 10.0.20-22/24   │   │
                          │                   │  (RDS Private)  │   │
                          │                   └─────────────────┘   │
                          └─────────────────────────────────────────┘
```

## Séquence de déploiement

1. **Bootstrap** (une seule fois) :
   ```bash
   cd bootstrap/
   terraform init
   terraform apply
   ```

2. **Staging** :
   ```bash
   cd environments/staging/
   terraform init
   terraform plan -out=tfplan
   terraform apply tfplan
   ```

3. **Production** :
   ```bash
   cd environments/production/
   terraform init
   terraform plan -out=tfplan
   terraform apply tfplan
   ```

## Composants

| Composant | Staging | Production |
|-----------|---------|------------|
| VPC CIDR | 10.0.0.0/16 | 10.1.0.0/16 |
| EKS Version | 1.31 | 1.31 |
| Nodes | 1 × t3.medium | 2 × t3.medium |
| Node Autoscaling | min 1 / max 2 | min 2 / max 4 |
| RDS Instance | db.t3.micro | db.t3.micro |
| RDS Multi-AZ | Non | Oui |
| RDS Storage | 20 GB → 50 GB | 50 GB → 200 GB |
| S3 Documents | ✓ | ✓ |
| ECR | Partagé | Partagé |
