# SF-INFRA-AF-07 — Monitoring + logs CloudWatch régionaux

> ⚠️ **HYPOTHÈSE / GELÉ — observation passive. NE PAS APPLIQUER.** Gate : voir `docs/afrique/README.md`.

## Objectif

Doter l'instance Afrique du même socle d'observabilité que l'Europe : alarmes CloudWatch (RDS, cluster),
rétention de logs maîtrisée, notifications SNS — dans `af-south-1`.

## Contexte

- **Réutilise `modules/monitoring/`** (alarmes CloudWatch + SNS) éprouvé en Europe (`SF-INFRA-02`,
  `SF-INFRA-05`, `SF-INFRA-07a`). Config régionale.
- Dépend de **AF-02** (cluster) et **AF-03** (RDS).
- Parité avec eu-west-3 : 3 alarmes RDS (CPU, connexions, stockage) + métriques cluster + rétention logs 7 j.

## Changements Terraform

```hcl
module "monitoring_afrique" {
  source        = "../../modules/monitoring"
  region        = "af-south-1"
  rds_instance  = module.rds_afrique.id
  cluster_name  = module.eks.cluster_name
  sns_email     = var.alerts_email
  log_retention = 7
}
```

## Plan d'application

```bash
cd environments/production-afrique
terraform plan -out=tfplan-af-mon   # revue : alarmes + SNS + log groups + rétention
terraform apply tfplan-af-mon
# Confirmer l'abonnement SNS (email PendingConfirmation → Confirmed)
```

## Coût delta (indicatif)

| Composant | Coût /mois |
|-----------|-----------|
| Alarmes CloudWatch + SNS | ~0-1 $ |
| Logs CloudWatch (rétention 7 j) | ~1-3 $ |

## Risques & rollback

| Risque | Mitigation |
|--------|-----------|
| Alarmes en `INSUFFICIENT_DATA` avant trafic | Normal au démarrage (cf. SF-INFRA-07a Europe) ; basculent à `OK` au 1er trafic |
| Coût logs non maîtrisé | Rétention 7 j + metric filters ciblés (pas de Container Insights, cf. backlog eu-west-3) |
| Abonnement SNS non confirmé | Confirmer l'email après apply |
