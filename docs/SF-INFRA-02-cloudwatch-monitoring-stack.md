# SF-INFRA-02 — Module `monitoring/` — stack CloudWatch (remplace Sentry)

## Objectif

Créer un module Terraform `modules/monitoring/` qui provisionne :
- Un topic SNS pour les alertes (email vers `tounga.franck@ng-itconsulting.com`)
- 5 alarmes CloudWatch couvrant les vrais scénarios à risque
- 1 metric filter sur les logs backend pour capturer les `ERROR` Java
- Activation et configuration de **AWS Budgets** (alerte sur seuil mensuel)

L'objectif est de **remplacer Sentry** (qui sera retiré côté app dans une SF séparée du repo `legalCase`) tout en gardant la visibilité opérationnelle nécessaire pour ne pas découvrir un problème via un client.

## Contexte

- **Sentry retiré** : décision utilisateur 2026-05-20. Pas de reconduction du contrat.
- **Couverture remplacée** :
  - Exceptions backend Java → CloudWatch Logs (stdout containerisé) + metric filter sur `level=ERROR` → alarme SNS
  - Pod evictions / restarts → CloudWatch metric `ContainerInsights` (sans la stack Container Insights complète — on lit directement les métriques EKS natives `pod_number_of_container_restarts`)
  - Erreurs frontend Angular → SF séparée côté `legalCase` ajoutera un `GlobalErrorHandler` qui POST vers `/api/client-errors` → log backend → CloudWatch Logs capture
- **AWS Cost Anomaly Detection** déjà actif (mail confirmation 2026-05-13) → conservé. Le module ajoute en plus un **AWS Budget mensuel** avec seuil dur pour rattraper le cas EKS extended support type 2026-04 (+440 $/mois découvert sur facture).

## Composants du module `modules/monitoring/`

```
modules/monitoring/
├── main.tf          # SNS topic + subscriptions + alarmes + budget
├── variables.tf
├── outputs.tf
```

### Ressources créées

1. **`aws_sns_topic.alerts`** — topic d'alerte unique
2. **`aws_sns_topic_subscription.email`** — abonnement email (variable `alert_email`)
3. **`aws_cloudwatch_metric_alarm.rds_cpu_high`** — RDS CPU > 80 % pendant 10 min
4. **`aws_cloudwatch_metric_alarm.rds_connections_high`** — RDS connexions actives > 80 % du max (paramétrique selon instance class)
5. **`aws_cloudwatch_metric_alarm.eks_pod_restarts`** — pods backend/frontend redémarrés > 3 fois en 1 h
6. **`aws_cloudwatch_metric_alarm.backend_error_rate`** — `level=ERROR` dans logs backend > 10 occurrences / 5 min
7. **`aws_cloudwatch_log_metric_filter.backend_errors`** — metric filter qui compte les `ERROR` dans `/aws/eks/.../containers/legalcase-backend-*`
8. **`aws_budgets_budget.monthly`** — budget mensuel (seuil paramétrique, défaut 500 $) avec notification à 80 % et 100 %

### Module appelé depuis `environments/production/main.tf` + `environments/staging/main.tf`

```hcl
module "monitoring" {
  source = "../../modules/monitoring"

  project              = var.project
  environment          = local.environment
  alert_email          = var.alert_email
  rds_instance_id      = module.rds.db_instance_id  # nouvelle output à ajouter
  eks_cluster_name     = data.terraform_remote_state.cluster.outputs.eks_cluster_name
  monthly_budget_usd   = var.monthly_budget_usd     # 500 prod / 200 staging
  tags                 = local.common_tags
}
```

## Plan d'application

```bash
cd /home/francky/dev/legalcase-infra
# 1. Création du module modules/monitoring/
# 2. Ajout de l'output db_instance_id dans modules/rds/outputs.tf
# 3. Appel du module dans environments/production/main.tf et environments/staging/main.tf
# 4. Ajout de variables alert_email + monthly_budget_usd

cd environments/staging
terraform init -upgrade
terraform plan -out=tfplan-monitoring
# Revue : ~12-15 ressources créées (SNS + 5 alarmes + metric filter + budget)
terraform apply tfplan-monitoring

cd ../production
terraform init -upgrade
terraform plan -out=tfplan-monitoring
terraform apply tfplan-monitoring
```

## Coût delta

- CloudWatch alarmes : **0 $** (10 alarmes incluses dans le Free Tier permanent, on en crée 5)
- CloudWatch logs metric filter : **0 $** (gratuit)
- SNS email : **0 $** (1 000 notifications email/mois gratuites)
- AWS Budgets : **0 $** (2 budgets gratuits par compte)
- **Total : 0 $/mois**

## Confirmation côté app (hors scope de cette SF)

Cette SF ne crée que l'infra des alertes. Le retrait Sentry et l'ajout d'un GlobalErrorHandler Angular seront traités dans une SF dédiée du repo `legalCase` (probablement F-XXX SF-XXX-01 « Migration observabilité Sentry → CloudWatch » à créer après merge de cette SF).

Vérifications minimales côté app après le merge SF-INFRA-02 :
- Les logs backend Java doivent inclure le mot `ERROR` au début de la ligne pour les exceptions (vérifier `application.yml` log pattern Logback)
- Les pods doivent envoyer `stdout` dans CloudWatch Logs (par défaut sur EKS Fargate ou avec Fluent Bit DaemonSet — à vérifier)

## Risques & rollback

| Risque | Mitigation |
|--------|-----------|
| Trop d'alertes (spam email) | Seuils volontairement conservateurs (10 ERROR / 5 min, pas 1 / 1 min). Affinable post-mise en route. |
| Logs backend pas dans CloudWatch Logs | Vérifier que Fluent Bit ou similaire est déployé sur le cluster. Sinon, étape préalable d'installation (additionnel ~2 h). |
| Budget mensuel mal calibré | Seuil 500 $ initial pour prod (couvre RDS + EKS + Claude API). Ajustable via variable. |

**Rollback** : `terraform destroy -target=module.monitoring` sur chaque env.

## Vérifications post-déploiement

1. **Recevoir l'email de confirmation SNS** et cliquer le lien d'abonnement
2. **Forcer une alarme test** : `aws cloudwatch set-alarm-state --alarm-name legalcase-production-rds-cpu-high --state-value ALARM --state-reason "test"` → vérifier réception email
3. **Metric filter actif** : faire une exception côté backend (route 404 ou similaire), attendre 5 min, vérifier que le compteur de la métrique custom `LegalCaseBackendErrors` monte dans CloudWatch
4. **Budget visible** dans la console AWS Billing → Budgets

## Commit

Branche `feat/infra-monitoring-cloudwatch` :
```
feat(monitoring): module CloudWatch alarmes + budget (remplace Sentry)

- Module modules/monitoring/ avec SNS topic + 5 alarmes ciblées
- RDS CPU + connections, EKS pod restarts, backend ERROR rate, budget mensuel
- Coût 0 $/mois (Free Tier CloudWatch + SNS + Budgets)
- Subscription email tounga.franck@ng-itconsulting.com
- Retrait Sentry sera traité côté repo legalCase
```
