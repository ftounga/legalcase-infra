# SF-INFRA-03 — Module `cdn/` — CloudFront devant S3 documents

## Objectif

Mettre CloudFront en frontal du bucket S3 `legalcase-{env}-documents-{account_id}` pour :
1. **Réduire la latence** d'accès aux PDF / OCR / images de pièces (50-150 ms gagnés sur les téléchargements depuis le navigateur de l'avocat)
2. **Réduire le coût NAT Gateway egress** (~0,09 $/GB → 0,005-0,02 $/GB CloudFront en Europe)
3. **Ajouter une couche de cache** sur les presigned URLs (cache HTTP 24 h côté edge)

## Contexte

- Aujourd'hui, le frontend Angular génère un presigned URL via backend → fetch direct S3 → latence variable (Paris → Paris ~30-80 ms ; mais depuis Bordeaux, Marseille, Belgique 80-200 ms).
- CloudFront avec POP en Europe (CDG, MRS, AMS, BRU, MAD) ramène la latence à 10-30 ms perçue.
- **Origin Access Control (OAC)** AWS récent (remplace OAI legacy) sécurise l'accès S3 — seul CloudFront peut lire le bucket.

## Composants du module `modules/cdn/`

```
modules/cdn/
├── main.tf          # CloudFront distribution + OAC + S3 bucket policy patch
├── variables.tf
├── outputs.tf
```

### Ressources créées

1. **`aws_cloudfront_origin_access_control.documents`** — OAC pour signer les requêtes vers S3
2. **`aws_cloudfront_distribution.documents`** — distribution CloudFront, classe de prix `PriceClass_100` (Europe + US/Canada uniquement, moins cher)
3. **`aws_s3_bucket_policy.allow_cloudfront`** — patch policy bucket pour autoriser CloudFront via OAC (et révoquer accès direct)

### Module appelé depuis `environments/production/main.tf` et `environments/staging/main.tf`

```hcl
module "cdn" {
  source = "../../modules/cdn"

  project              = var.project
  environment          = local.environment
  s3_bucket_id         = module.s3.documents_bucket_id     # output existant à vérifier
  s3_bucket_arn        = module.s3.documents_bucket_arn
  s3_bucket_regional   = module.s3.documents_bucket_regional_domain_name
  price_class          = "PriceClass_100"
  default_ttl_seconds  = 86400   # 24 h cache par défaut
  tags                 = local.common_tags
}
```

## Plan d'application

```bash
cd /home/francky/dev/legalcase-infra
# 1. Création du module modules/cdn/
# 2. Vérifier/ajouter les outputs nécessaires dans modules/s3/outputs.tf
# 3. Appel du module dans environments/{staging,production}/main.tf

cd environments/staging
terraform init -upgrade
terraform plan -out=tfplan-cdn
# Revue : ~3-4 ressources (distribution + OAC + bucket policy patch)
terraform apply tfplan-cdn

# Validation manuelle sur staging avant prod
# Tester un téléchargement via CloudFront URL

cd ../production
terraform plan -out=tfplan-cdn
terraform apply tfplan-cdn
```

## Coût delta

| Composant | Coût | Estimation |
|-----------|------|-----------|
| CloudFront data transfer Europe | 0,085 $/GB après Free Tier | Volume mensuel ~5-20 GB → **~0,5-2 $/mois** (probablement 0 $ pendant 12 mois Free Tier) |
| CloudFront requêtes HTTPS | 0,0100 $/10k | ~50k req/mois → **0,05 $/mois** |
| OAC + bucket policy | 0 $ | gratuit |
| **Économie NAT GW egress** | 0,045 $/GB | -0,225 à -0,90 $/mois |
| **Net** | | **~0-1 $/mois** |

Pendant les 12 premiers mois du compte AWS : Free Tier CloudFront inclut 1 TB egress + 10 M HTTPS requêtes → **0 $ probable**.

## Changement côté app (hors scope de cette SF)

Le frontend Angular ou le backend doit utiliser l'URL CloudFront au lieu de l'URL S3 direct pour générer les liens de téléchargement. À faire côté `legalCase` :
1. Ajouter une variable d'env `CLOUDFRONT_DOMAIN` dans `k8s/overlays/*/kustomization.yaml`
2. Backend `S3PresignedUrlService` (ou équivalent) doit construire l'URL via le domaine CloudFront, pas directement le bucket S3
3. CORS S3 à étendre si nécessaire (probablement déjà OK car `allowed_origins = ["*"]`)

SF de suite côté `legalCase` à créer après merge de SF-INFRA-03.

## Risques & rollback

| Risque | Mitigation |
|--------|-----------|
| Mauvaise configuration OAC → S3 devient inaccessible | Plan en 2 temps : d'abord ajouter OAC + autoriser CloudFront, vérifier ; puis (étape suivante, dans une SF de durcissement) révoquer accès direct S3 |
| Cache CloudFront sert un fichier obsolète | TTL 24 h par défaut. Pour les presigned URLs courts (`expiresIn=900`), bypasser le cache via header `Cache-Control: no-store` côté backend ; ou cache key inclut le query string |
| Latence d'invalidation | Invalidation manuelle si besoin (gratuit 1000 paths/mois) |

**Rollback** : `terraform destroy -target=module.cdn`. Le bucket S3 reste accessible directement.

## Vérifications post-déploiement

1. **Distribution déployée** : `aws cloudfront list-distributions --query 'DistributionList.Items[?Comment==\`legalcase-production-documents\`].{id:Id,domain:DomainName,status:Status}'`
   → Attendu : `status = "Deployed"` (peut prendre 5-15 min)
2. **OAC effectif** : `curl https://{cloudfront_domain}/some-test-file.pdf` → 200 OK ; `curl https://{bucket}.s3.eu-west-3.amazonaws.com/some-test-file.pdf` → 403 Forbidden (si on a révoqué l'accès direct)
3. **Latence** : `curl -w "%{time_total}\n" -o /dev/null https://{cloudfront}/file.pdf` depuis 2-3 régions (Paris, Bruxelles, Bordeaux) → toutes < 100 ms attendues

## Commit

Branche `feat/infra-cdn-cloudfront-s3` :
```
feat(cdn): CloudFront devant S3 documents

- Module modules/cdn/ avec distribution + OAC + bucket policy
- PriceClass_100 (Europe + US), TTL 24 h par défaut
- Réduit latence téléchargement pièces 50-150 ms
- Coût ~0-1 $/mois (Free Tier 12 mois inclus)
- Branchement app via CLOUDFRONT_DOMAIN à faire côté repo legalCase
```
