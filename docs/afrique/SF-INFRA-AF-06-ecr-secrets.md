# SF-INFRA-AF-06 — ECR images + Secrets Manager régional

> ⚠️ **HYPOTHÈSE / GELÉ — observation passive. NE PAS APPLIQUER.** Gate : voir `docs/afrique/README.md`.

## Objectif

Rendre les images conteneurs disponibles au cluster Afrique et stocker les secrets (DB, clés API, tokens) en
**Secrets Manager `af-south-1`**, sans valeur sensible en dur (règle CLAUDE.md).

## Contexte

- **Réutilise `modules/ecr/`** (repositories backend + frontend) et le pattern Secrets Manager existant.
- Dépend de **AF-01** (réseau pour endpoints privés éventuels).
- **Deux options ECR à trancher à l'engagement** :
  1. **Réplication cross-région** des repos ECR `eu-west-3` → `af-south-1` (même image, un seul build CI).
  2. **Repos ECR régionaux** dédiés + push CI multi-région.
  → Recommandé : **réplication ECR** (option 1) — une seule chaîne de build, l'image applicative est identique
  (D1 : même codebase). Les images ne contiennent pas de données personnelles → pas de conflit D9.

## Changements Terraform

```hcl
# Option 1 — réplication ECR vers af-south-1 (config sur le registre eu-west-3)
resource "aws_ecr_replication_configuration" "afrique" {
  replication_configuration {
    rule { destination { region = "af-south-1" registry_id = var.account_id } }
  }
}

module "secrets_afrique" {
  source = "../../modules/secrets"   # ou ressources aws_secretsmanager_secret régionales
  region = "af-south-1"
  secrets = ["db-credentials", "anthropic-api-key", "cinetpay-keys", "oidc-clients"]
}
```

## Plan d'application

```bash
cd environments/production-afrique
terraform plan -out=tfplan-af-ecr   # revue : réplication ECR + secrets (placeholders, valeurs hors Terraform)
terraform apply tfplan-af-ecr
# Renseigner les valeurs de secrets via CLI/console (jamais commitées)
```

## Coût delta (indicatif)

| Composant | Coût /mois |
|-----------|-----------|
| ECR stockage + réplication | ~1-3 $ |
| Secrets Manager (~4 secrets) | ~2 $ |

## Risques & rollback

| Risque | Mitigation |
|--------|-----------|
| Secret en dur dans le code/CI | Tout en Secrets Manager, jamais commité (règle CLAUDE.md) |
| Image absente en `af-south-1` au déploiement | Réplication ECR validée avant le 1er rollout |
| Clés CinetPay/OIDC exposées | Secrets régionaux + accès IRSA scoping minimal |
