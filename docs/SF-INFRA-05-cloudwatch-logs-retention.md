# SF-INFRA-05 — Rétention logs CloudWatch EKS control plane 14j → 7j + cleanup log group orphelin

## Objectif

Réduire la rétention du log group EKS control plane de 14 jours à 7 jours et supprimer le log group orphelin du cluster staging legacy (cluster supprimé lors du passage au cluster shared — commit `626e064`).

## Contexte

Audit du 2026-05-20 a révélé :
- `/aws/eks/legalcase-shared/cluster` : 2,3 GB sur 14 j de rétention → ~$1,25/mois côté stockage CloudWatch Logs (sans compter l'ingestion).
- `/aws/eks/legalcase-staging/cluster` : 0,0 MB — log group orphelin, plus aucun cluster ne pousse dedans depuis la migration vers le cluster shared.

Aucune des deux ressources n'était sous gestion Terraform : EKS crée les log groups automatiquement quand `enabled_cluster_log_types` est défini, avec une rétention par défaut « Never expire ». Cela explique l'accumulation.

## Changements

### Module `modules/eks/`

1. **Nouvelle variable `cluster_logs_retention_days`** (default 7) dans `modules/eks/variables.tf`
2. **Nouvelle ressource `aws_cloudwatch_log_group.eks_cluster`** dans `modules/eks/main.tf` :
   - Nom : `/aws/eks/${var.project}-${var.environment}/cluster`
   - `retention_in_days = var.cluster_logs_retention_days` (7 j par défaut)
3. **`depends_on` ajouté** sur `aws_eks_cluster.main` pour que le log group soit créé avant le cluster (évite la création implicite par EKS sans rétention)

### Cleanup AWS

- **`/aws/eks/legalcase-staging/cluster` supprimé** via `aws logs delete-log-group` (hors Terraform — log group orphelin non géré, suppression directe suffit).

## Plan d'application

```bash
cd /home/francky/dev/legalcase-infra/cluster

# Le log group existant doit être importé dans le state Terraform
# avant l'apply (sinon Terraform tente de le créer et échoue avec
# « already exists »).
terraform init
terraform import 'module.eks.aws_cloudwatch_log_group.eks_cluster' '/aws/eks/legalcase-shared/cluster'

# Plan attendu : retention_in_days 14 → 7 (in-place update)
terraform plan -out=tfplan-logs
terraform apply tfplan-logs

# Suppression du log group orphelin (en dehors de Terraform)
aws logs delete-log-group --region eu-west-3 --log-group-name /aws/eks/legalcase-staging/cluster
```

## Coût delta

- Stockage CloudWatch Logs : ~-$0,60/mois (passage de 2,3 GB à ~1,1 GB après expiration des logs > 7 j)
- Ingestion CloudWatch Logs : inchangée (~5 GB/mois = $2,50/mois)
- Total : **~-$0,60 à -$1,25/mois** selon l'évolution du volume ingéré
- Bénéfice principal : **hygiène IaC** — la rétention est désormais sous Terraform, plus de dépendance au comportement par défaut d'EKS.

## Risques & rollback

| Risque | Mitigation |
|--------|-----------|
| Perte de logs > 7 j en cas de besoin de debugging long terme | Acceptable : les logs `api` + `authenticator` sont consultés en réactif, pas en forensic > 7 j |
| Suppression accidentelle d'un log group encore utilisé | Le log group staging était à 0 MB depuis le 2026-04 (migration cluster shared). Vérifié vide avant suppression. |

**Rollback** : remettre `var.cluster_logs_retention_days = 14` (ou 30) dans le module EKS. Pour le log group staging supprimé : aucun rollback nécessaire (était vide).

## Vérifications post-déploiement

1. ✅ `aws logs describe-log-groups --region eu-west-3` → 1 seul log group EKS visible, `retentionInDays: 7`
2. ✅ Pas d'erreur côté EKS : `aws eks describe-cluster --name legalcase-shared --query 'cluster.logging'` confirme que `api` + `authenticator` continuent de logger
3. ✅ Le `terraform plan` suivant ne signale plus de drift sur le log group

## Commit

Branche `feat/infra-cleanup-logs-snapshots-audit` :
```
feat(eks): IaC log group + rétention 7j + suppression staging orphelin (SF-INFRA-05)
```
