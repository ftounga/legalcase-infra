# SF-INFRA-AF-04 — S3 documents + backups régionaux Afrique

> ⚠️ **HYPOTHÈSE / GELÉ — observation passive. NE PAS APPLIQUER.** Gate : voir `docs/afrique/README.md`.

## Objectif

Provisionner le stockage objet des documents (pièces de dossiers) et les sauvegardes **dans `af-south-1`**,
en accès privé strict, pour la résidence des données OHADA (D9).

## Contexte

- **Réutilise `modules/s3/`** (bucket documents + bucket policy privée + chiffrement) et **`modules/backup/`**
  (plan AWS Backup : RDS + volumes). Config régionale.
- Dépend de **AF-01**. Le bucket est l'origine du CDN régional (AF-05).
- Règle CLAUDE.md : **accès privé strict, pas de public access**, chiffrement au repos.

## Changements Terraform

```hcl
module "s3_afrique" {
  source      = "../../modules/s3"
  region      = "af-south-1"
  bucket_name = "legalcase-afrique-documents-<account_id>"
  block_public_access = true
  encryption  = "AES256"        # ou KMS régional
}

module "backup_afrique" {
  source          = "../../modules/backup"
  region          = "af-south-1"
  retention_days  = 7
  resources       = [module.rds_afrique.arn]   # + volumes EBS éventuels
}
```

## Plan d'application

```bash
cd environments/production-afrique
terraform plan -out=tfplan-af-s3    # revue : bucket privé + policy + backup plan régional
terraform apply tfplan-af-s3
```

## Coût delta (indicatif)

| Composant | Coût /mois |
|-----------|-----------|
| S3 (volume initial faible) | ~1-5 $ |
| AWS Backup (snapshots RDS 7 j) | ~2-4 $ |

## Risques & rollback

| Risque | Mitigation |
|--------|-----------|
| Bucket exposé publiquement | `block_public_access = true` + bucket policy privée (règle CLAUDE.md) |
| Backups répliqués hors région (non-conformité D9) | Backups régionaux uniquement, pas de copie cross-région |
| Accès S3 depuis l'app | Origin Access Control via CDN (AF-05) ; IRSA pour l'accès backend |
