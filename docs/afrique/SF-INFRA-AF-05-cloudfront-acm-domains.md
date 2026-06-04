# SF-INFRA-AF-05 — CloudFront + ACM, domaines `legalcase.africa`

> ⚠️ **HYPOTHÈSE / GELÉ — observation passive. NE PAS APPLIQUER.** Gate : voir `docs/afrique/README.md`.

## Objectif

Exposer l'instance Afrique derrière CloudFront avec TLS, sur les domaines **`legalcase.africa`** (prod) et
**`staging.legalcase.africa`** (staging) — D10. CloudFront sert le frontend et les URLs de téléchargement
des documents (origine = bucket S3 régional AF-04, via Origin Access Control).

## Contexte

- **Réutilise `modules/cdn/`** (CloudFront + Origin Access Control + bucket policy) déjà éprouvé en Europe
  (cf. `SF-INFRA-03`). Ajout : certificats ACM et alias de domaine.
- Dépend de **AF-04** (bucket origine).
- **Prérequis hors Terraform** : le domaine `legalcase.africa` doit être **déposé** (à la main du PO, cf.
  cadrage D10) et sa zone DNS gérée (Route 53 ou registrar).
- ⚠️ **ACM pour CloudFront** : le certificat CloudFront doit être en **`us-east-1`** (contrainte AWS), même si
  l'origine est en `af-south-1`. Le certificat ne contient pas de données personnelles → pas de conflit D9.

## Changements Terraform

```hcl
module "cdn_afrique" {
  source              = "../../modules/cdn"
  aliases             = ["legalcase.africa", "staging.legalcase.africa"]
  acm_certificate_arn = aws_acm_certificate.africa.arn   # certificat en us-east-1
  s3_origin           = module.s3_afrique.bucket_domain_name
}
# Certificat ACM en us-east-1 (provider aliasé) + validation DNS sur la zone legalcase.africa
```

## Plan d'application

```bash
# 1. Déposer legalcase.africa + créer la zone DNS (manuel, hors verrou)
cd environments/production-afrique
terraform plan -out=tfplan-af-cdn   # revue : ACM + distribution CloudFront + records DNS de validation
terraform apply tfplan-af-cdn
# 2. Pointer les enregistrements DNS prod/staging vers la distribution CloudFront
```

## Coût delta (indicatif)

| Composant | Coût /mois |
|-----------|-----------|
| CloudFront (Free Tier 12 mois puis trafic) | ~0-2 $ |
| ACM | 0 $ |
| Domaine `legalcase.africa` | ~15-30 $/an (registrar) |

## Risques & rollback

| Risque | Mitigation |
|--------|-----------|
| Certificat ACM mal placé (région) | ACM CloudFront **obligatoirement** en `us-east-1` |
| Domaine non déposé | Prérequis manuel PO (D10) avant apply |
| Propagation DNS lente | Valider ACM par DNS en amont, prévoir le délai |
