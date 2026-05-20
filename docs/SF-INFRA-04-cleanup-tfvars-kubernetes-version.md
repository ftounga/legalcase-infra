# SF-INFRA-04 — Cleanup `kubernetes_version` mort code dans `environments/*/terraform.tfvars`

## Objectif

Supprimer la variable `kubernetes_version` des fichiers `environments/staging/terraform.tfvars` et `environments/production/terraform.tfvars`, qui est devenue du mort code depuis le refactor en cluster EKS partagé (commit `626e064` — « 1 cluster partagé — environments n'appliquent plus que RDS + S3 »).

## Contexte

- Le cluster EKS est désormais provisionné par `cluster/main.tf` (workspace partagé), qui appelle `module "eks"` avec sa propre variable `kubernetes_version`.
- Les `environments/{staging,production}/main.tf` n'appellent plus le module EKS — ils ne consomment que `modules/rds`, `modules/s3`, `modules/backup`.
- Pourtant, `environments/production/terraform.tfvars:11` et `environments/staging/terraform.tfvars` contiennent encore `kubernetes_version = "1.31"`, et les `variables.tf` correspondants déclarent cette variable.
- Cluster réel = `1.34` (vérifié 2026-05-20 via `aws eks describe-cluster --name legalcase-shared`), commit `470c11f` (« upgrade EKS 1.31 → 1.34 sortie extended support »).
- **Risque actuel** : un lecteur du repo croit que la prod est en 1.31 alors qu'elle est en 1.34. Source de confusion lors des audits.

## Changements

Fichiers modifiés :

1. `environments/production/terraform.tfvars` — supprimer `kubernetes_version = "1.31"` + variables `node_*` qui ne sont plus utilisées par production
2. `environments/production/variables.tf` — supprimer la déclaration `variable "kubernetes_version"` + les variables `node_*` orphelines
3. `environments/staging/terraform.tfvars` — idem
4. `environments/staging/variables.tf` — idem

Ne pas toucher à `cluster/variables.tf` ni `cluster/terraform.tfvars` (ces fichiers pilotent vraiment la version EKS).

## Plan d'application

```bash
cd /home/francky/dev/legalcase-infra
# Suppressions ciblées dans les 4 fichiers
cd environments/staging
terraform plan
# Attendu : "No changes" (les variables retirées n'étaient pas utilisées)
cd ../production
terraform plan
# Attendu : "No changes"
```

Si `terraform plan` annonce des changements, on s'arrête et on investigue avant tout apply.

## Coût delta

0 $. Cleanup pur de doc/config.

## Risques & rollback

| Risque | Mitigation |
|--------|-----------|
| Une variable supprimée était en réalité référencée ailleurs | `terraform plan` détecte immédiatement (`Error: Reference to undeclared input variable`). |
| Confusion entre cluster/ et environments/ remise en cause | Documenter explicitement dans le commit message + ADR éventuelle dans `docs/ARCHITECTURE_INFRA.md`. |

**Rollback** : git revert du commit.

## Vérifications post-déploiement

Pas de `terraform apply` requis (cleanup pur). Vérifications :
1. `terraform plan` sur chaque environnement → « No changes »
2. `grep -rn "kubernetes_version" environments/` → 0 résultat attendu
3. ADR-006 ajoutée à `docs/ARCHITECTURE_INFRA.md` documentant la séparation `cluster/` vs `environments/` pour éviter récidive

## Commit

Branche `feat/infra-cleanup-tfvars-k8s-version` :
```
chore(envs): supprimer kubernetes_version mort code dans environments/*

- Le cluster EKS est piloté par cluster/main.tf depuis le commit 626e064
- environments/{staging,production} n'appellent plus le module EKS
- Cluster réel = 1.34 (vérifié AWS), pas 1.31 comme indiqué dans tfvars
- Ajoute ADR-006 dans docs/ARCHITECTURE_INFRA.md
```
