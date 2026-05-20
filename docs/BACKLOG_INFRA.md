# Backlog infrastructure — LegalCase

Ce document liste les évolutions infra planifiées pour l'environnement AWS (eu-west-3).
Chaque SF a un fichier dédié `docs/SF-INFRA-XX-<titre>.md` qui détaille l'objectif, le plan d'application, le coût delta et les vérifications post-déploiement.

Conventions :
- Branche : `feat/infra-<sujet>` (cf. `CLAUDE.md`)
- Pas de `terraform apply` automatique — toujours manuel avec revue du plan
- Un commit par ressource logique

## Légende statut

- `À faire` — pas démarrée
- `En cours` — branche ouverte, modifs en cours
- `Validée plan` — `terraform plan` revu, en attente d'apply
- `Appliquée` — `terraform apply` exécuté + vérifications post-déploiement OK
- `Bloquée` — dépendance non levée

## Tableau

| ID | Titre | Statut | Effort | Coût delta /mois | Priorité |
|----|-------|--------|--------|------------------|----------|
| SF-INFRA-01 | RDS prod upgrade `db.t3.micro` → `db.t4g.small` (ARM Graviton2, 2 vCPU dédiés, 2 GB RAM) | Appliquée 2026-05-20 (swap effectif fenêtre maintenance lun 25/05 ~05:00 Paris) | 30 min Terraform | +~15 $ | ✅ Fait |
| SF-INFRA-02 | Module `monitoring/` — alertes CloudWatch (3 alarmes RDS + SNS email, sans budget car 3 budgets manuels déjà en place) | Appliquée 2026-05-20 — 6 alarmes créées (3 staging + 3 prod), 2 subscriptions SNS en `PendingConfirmation` | 1 j | 0 $ | ✅ Fait |
| SF-INFRA-03 | Module `cdn/` — CloudFront devant S3 documents + Origin Access Control + bucket policy | Appliquée 2026-05-20 — staging `d2oaldre5efpif.cloudfront.net` déployé, prod en cours | 6 h | ~0-2 $ (Free Tier 12 mois) | ✅ Fait |
| SF-INFRA-04 | Cleanup `environments/*/terraform.tfvars` — supprimer `kubernetes_version` (mort code depuis migration vers `cluster/` shared) | Appliquée 2026-05-20 — `terraform plan staging = No changes` confirmé | 5 min | 0 $ | ✅ Fait |

## Suite envisagée (créer SF à venir)

| ID | Titre | Statut | Notes |
|----|-------|--------|-------|
| SF-INFRA-05 (à créer) | Réduire rétention logs CloudWatch control plane EKS de 14j à 7j | À faire | Économie ~$5/mois |
| SF-INFRA-06 (à créer) | Audit EBS snapshots manuels (RabbitMQ PVC + RDS) — purger les > 7j | À faire | Économie ~$5-15/mois selon historique |
| SF-INFRA-07 (à créer côté repo legalCase) | Déployer Fluent Bit DaemonSet sur EKS pour shipper les logs Spring Boot vers CloudWatch Logs + ajouter alarme `backend ERROR rate` côté infra | À faire | ~3-4 h. Pré-requis pour retirer Sentry complètement. |
| SF-INFRA-08 (à créer côté repo legalCase) | Brancher CloudFront côté backend Spring Boot (`CLOUDFRONT_DOMAIN` env var) pour générer les URLs de téléchargement via le CDN au lieu de S3 direct | À faire | ~2 h backend + 30 min K8s configmap |

## Pas dans ce backlog (décisions explicites)

- **RabbitMQ cluster ou migration SQS** — pas urgent à 0 client payant. SPOF acceptable, parade applicative (job reaper backend) sera ajoutée côté repo app `legalCase` quand on aura 5+ clients payants. À reconsidérer V9+ ou à 10+ clients.
- **Redis / ElastiCache** — pas nécessaire au volume actuel. Prompt caching Anthropic (F-142-04) déjà acquis (-85 % prefill). À reconsidérer si > 200 dossiers/jour ou si pattern d'accès dashboard répétitif émerge.
- **Container Insights / Prometheus / Grafana** — sur-engineered au stade actuel. Les 4 alarmes CloudWatch + AWS Cost Anomaly Detection + Sentry remplacé par CloudWatch Logs metric filters suffisent.

## Historique

| Date | Évolution |
|------|-----------|
| 2026-05-20 | Création du backlog. Inclus SF-INFRA-01 à 04. Décisions explicites : RabbitMQ cluster et Redis non retenus à ce stade. |
| 2026-05-20 | SF-INFRA-01, 02, 03, 04 appliquées. Audit Cost Explorer mai 2026 effectué : EKS extended support encore actif 1-14/05 ($156 facturé), terminé le 16/05. À régime stable (juin onwards) : ~$412/mois TTC vs $815/mois en avril — économie $400/mois. SF-INFRA-05 à 08 identifiées comme bonus à venir. |
