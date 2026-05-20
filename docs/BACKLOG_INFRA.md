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
| SF-INFRA-01 | RDS prod upgrade `db.t3.micro` → `db.t4g.small` (ARM Graviton2, 2 vCPU dédiés, 2 GB RAM) | À faire | 30 min Terraform + ~3 min failover Multi-AZ | +~15 $ | 🔴 Maintenant |
| SF-INFRA-02 | Module `monitoring/` — alertes CloudWatch (RDS CPU/connexions, EKS pod restarts, backend ERROR rate via log metric filter, billing anomaly) — remplace Sentry | À faire | 1 j | 0 $ (Free Tier 10 alarmes) | 🔴 Maintenant |
| SF-INFRA-03 | Module `cdn/` — CloudFront devant S3 documents + Origin Access Control + presigned URL cache 24 h | À faire | 6 h | ~0-5 $ (Free Tier 12 mois) | 🟡 Cette semaine |
| SF-INFRA-04 | Cleanup `environments/*/terraform.tfvars` — supprimer la variable `kubernetes_version` (mort code depuis migration vers `cluster/` shared) | À faire | 5 min | 0 $ | 🟢 Bonus |

## Pas dans ce backlog (décisions explicites)

- **RabbitMQ cluster ou migration SQS** — pas urgent à 0 client payant. SPOF acceptable, parade applicative (job reaper backend) sera ajoutée côté repo app `legalCase` quand on aura 5+ clients payants. À reconsidérer V9+ ou à 10+ clients.
- **Redis / ElastiCache** — pas nécessaire au volume actuel. Prompt caching Anthropic (F-142-04) déjà acquis (-85 % prefill). À reconsidérer si > 200 dossiers/jour ou si pattern d'accès dashboard répétitif émerge.
- **Container Insights / Prometheus / Grafana** — sur-engineered au stade actuel. Les 4 alarmes CloudWatch + AWS Cost Anomaly Detection + Sentry remplacé par CloudWatch Logs metric filters suffisent.

## Historique

| Date | Évolution |
|------|-----------|
| 2026-05-20 | Création du backlog. Inclus SF-INFRA-01 à 04. Décisions explicites : RabbitMQ cluster et Redis non retenus à ce stade. |
