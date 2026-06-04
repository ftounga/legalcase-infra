# SF-INFRA-AF-03 — RDS PostgreSQL régional (résidence des données)

> ⚠️ **HYPOTHÈSE / GELÉ — observation passive. NE PAS APPLIQUER.** Gate : voir `docs/afrique/README.md`.

## Objectif

Provisionner la base PostgreSQL de l'instance Afrique **dans `af-south-1`**, en subnet privé, pour satisfaire
la résidence des données OHADA (D9) — les données des workspaces africains ne quittent pas la région.

## Contexte

- **Réutilise `modules/rds/`** (RDS PostgreSQL 16 + subnet group + SG privé). Config régionale.
- Dépend de **AF-01** (subnets privés).
- **Séparation staging/prod** : décision à confirmer à l'engagement — soit deux instances (`staging` petite +
  `production`), soit une instance avec deux bases logiques. Recommandé au démarrage : **une instance
  `db.t4g.small` prod + une `db.t3.micro` staging** (parité avec le pattern eu-west-3, coût maîtrisé).

## Changements Terraform

```hcl
module "rds_afrique" {
  source            = "../../modules/rds"
  region            = "af-south-1"
  engine_version    = "16"
  instance_class    = "db.t4g.small"             # prod ; staging = db.t3.micro
  multi_az          = true                        # résidence + HA ; ajuster selon budget
  private_subnets   = module.networking.private_subnet_ids
  publicly_accessible = false                     # règle CLAUDE.md : jamais d'accès public
  # mot de passe via Secrets Manager (AF-06), jamais en dur
}
```

## Plan d'application

```bash
cd environments/production-afrique
terraform plan -out=tfplan-af-rds   # revue : aws_db_instance + subnet group + SG, accès privé only
terraform apply tfplan-af-rds
```

## Coût delta (indicatif)

| Composant | Coût /mois |
|-----------|-----------|
| RDS `db.t4g.small` Multi-AZ (prod) | ~32 $ |
| RDS `db.t3.micro` (staging) | ~17 $ |
| Storage gp3 50 GB + backups 7 j | ~6-8 $ |

## Risques & rollback

| Risque | Mitigation |
|--------|-----------|
| Données personnelles hors région (non-conformité D9) | RDS strictement en `af-south-1`, aucune réplication cross-région ; backups régionaux (AF-04) |
| Secret DB en dur | Mot de passe généré + stocké dans Secrets Manager régional (AF-06), règle CLAUDE.md |
| Disponibilité `db.t4g` (Graviton) en `af-south-1` | Vérifier la dispo de la classe avant apply ; fallback `db.t3.small` |
