# SF-INFRA-07a — Infrastructure Fluent Bit (IRSA + log group + metric filter + alarme)

## Objectif

Partie infrastructure (Terraform) du remplacement Sentry par CloudWatch Logs. Provisionne les ressources AWS nécessaires pour que le DaemonSet Fluent Bit (déployé dans le repo `legalCase`, SF-INFRA-07b) puisse shipper les logs des pods Spring Boot vers CloudWatch Logs, et que l'alarme `backend_error_rate` se déclenche au-dessus d'un seuil d'erreurs.

## Contexte

- Aucun mécanisme de remontée des `stdout` des pods backend Java vers CloudWatch aujourd'hui (cf. audit du 2026-05-20 — pas de DaemonSet logs sur le cluster `legalcase-shared`).
- L'alarme `backend ERROR rate` du module `monitoring/` (SF-INFRA-02) ne pouvait pas être activée tant que la métrique source n'existait pas.
- Sentry à retirer (décision user 2026-05-20). CloudWatch Logs + log metric filters remplacent la capture d'erreur backend.

## Composants ajoutés

### `modules/eks/` (workspace `cluster/`)

1. **`aws_iam_role.fluent_bit`** + assume role policy — IRSA pour le SA `amazon-cloudwatch/fluent-bit`
2. **`aws_iam_role_policy_attachment.fluent_bit_cloudwatch`** — policy managed AWS `CloudWatchAgentServerPolicy`
3. **`aws_cloudwatch_log_group.applications`** — log group `/aws/eks/legalcase-shared/applications`, retention 7 j (paramétrable via `application_logs_retention_days`)
4. **`aws_cloudwatch_log_metric_filter.backend_errors`** — pattern `"ERROR"` sur le log group, métrique custom `LegalCase/Application:BackendErrors`
5. Outputs ajoutés à `modules/eks/` + propagation `cluster/outputs.tf` :
   - `fluent_bit_role_arn`
   - `applications_log_group_name`

### `modules/monitoring/`

6. **`aws_cloudwatch_metric_alarm.backend_error_rate`** — alarme conditionnelle (count = `var.enable_backend_error_alarm ? 1 : 0`)
   - Seuil : > 10 erreurs par 5 min (paramétrable via `backend_error_rate_threshold`)
   - Push vers `legalcase-production-alerts` SNS topic
   - `enable_backend_error_alarm = true` activé dans `environments/production/main.tf` uniquement

## Plan d'application

```bash
# 1. Workspace cluster (IRSA + log group + metric filter)
cd /home/francky/dev/legalcase-infra/cluster
terraform init
terraform plan -out=tfplan-fluent-bit
# Attendu : 4 to add (role, policy attach, log group, metric filter)
terraform apply tfplan-fluent-bit

# 2. Workspace production (activation de l'alarme)
cd ../environments/production
terraform init
terraform plan -out=tfplan-fbalarm -target=module.monitoring
# Attendu : 1 to add (aws_cloudwatch_metric_alarm.backend_error_rate[0])
terraform apply tfplan-fbalarm
```

## Coût delta

- Log group `/aws/eks/legalcase-shared/applications` — Free Tier 5 GB ingestion + 5 GB stockage. Au-delà : $0,50/GB ingestion + $0,03/GB stockage.
- Volume estimé Spring Boot 2 replicas prod : ~1 GB/mois → **0 $** (largement dans le Free Tier).
- Metric filter + alarme + métrique custom : **0 $** (alarme 4 incluse dans Free Tier, métrique custom 10 incluses).
- **Total : 0 $/mois**.

## Dépendance amont

La partie K8s manifest (DaemonSet Fluent Bit) est dans le repo `legalCase`, SF-INFRA-07b. Sans ce manifest déployé, la métrique `BackendErrors` reste vide et l'alarme reste en `INSUFFICIENT_DATA`.

## Vérifications post-deploy

1. ✅ `aws iam get-role --role-name legalcase-shared-fluent-bit-role` → role créé
2. ✅ `aws logs describe-log-groups --log-group-name-prefix /aws/eks/legalcase-shared/applications` → log group créé, retention 7 j
3. ✅ `aws logs describe-metric-filters --log-group-name /aws/eks/legalcase-shared/applications` → filter `legalcase-shared-backend-errors` actif, pattern `"ERROR"`
4. ✅ Alarme `legalcase-production-backend-error-rate` créée en état `INSUFFICIENT_DATA`

## Commit

Branche `feat/infra-fluent-bit-irsa-monitoring` :
```
feat(eks,monitoring): IRSA Fluent Bit + log group applications + metric filter ERROR + alarme prod (SF-INFRA-07a)
```
