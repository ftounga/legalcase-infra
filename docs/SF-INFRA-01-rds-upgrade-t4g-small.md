# SF-INFRA-01 — RDS prod upgrade `db.t3.micro` → `db.t4g.small`

## Objectif

Passer la base PostgreSQL de production d'une instance burstable (`db.t3.micro`, 2 vCPU burst / 1 GB RAM) à une instance ARM Graviton2 dédiée (`db.t4g.small`, 2 vCPU dédiés / 2 GB RAM) pour absorber la charge du pipeline d'analyse IA sans throttling CPU credits.

## Contexte

- **Problème** : `db.t3.micro` est conçue pour des charges intermittentes. Le pipeline d'analyse IA (Liquibase migrations + Hibernate batch inserts de 100+ chunks par doc + lectures dashboard) consomme du CPU et de l'IOPS de façon soutenue. Quand les CPU credits sont épuisés, la perf chute de 50-70 %.
- **Cible** `db.t4g.small` : Graviton2 ARM, 2 vCPU dédiés (pas de mécanique de credits), 2 GB RAM, perf 30-40 % supérieure à `db.t3.small` pour ~30 % moins cher.
- **Compatibilité** : Postgres 16.10 supporté nativement sur Graviton.
- **Multi-AZ** déjà en place — l'upgrade se fait avec failover automatique (~1-3 min de downtime côté primaire).

## Changements Terraform

Un seul fichier modifié :

`environments/production/terraform.tfvars` ligne 18 :

```diff
-db_instance_class        = "db.t3.micro"
+db_instance_class        = "db.t4g.small"
```

Aucun autre changement (le module `modules/rds/` accepte déjà `instance_class` comme variable, voir `modules/rds/main.tf:67`).

Staging reste sur `db.t3.micro` (charge négligeable, économie).

## Plan d'application

```bash
cd /home/francky/dev/legalcase-infra/environments/production
terraform init
terraform plan -out=tfplan-rds-t4g
# Revue plan : doit montrer 1 changement = modification in-place de aws_db_instance.main
# (pas de destroy/recreate — instance_class est modifiable à chaud avec failover)
terraform apply tfplan-rds-t4g
```

Plan attendu :
- `~ resource "aws_db_instance" "main"` (modify in place)
- `instance_class: "db.t3.micro" -> "db.t4g.small"`
- Aucune autre ressource impactée

## Coût delta

| Composant | Avant | Après | Delta |
|-----------|-------|-------|-------|
| RDS Multi-AZ (730 h/mois) | ~17 $/mois | ~32 $/mois | **+15 $/mois** |
| Storage 50 GB gp3 | inchangé | inchangé | 0 |
| Backup 7 j | inchangé | inchangé | 0 |

## Risques & rollback

| Risque | Mitigation |
|--------|-----------|
| Failover Multi-AZ pendant l'upgrade — downtime ~1-3 min sur la connexion primaire | Lancer hors heures de démo. Backend Spring HikariCP + retry RabbitMQ absorbent la reconnexion. Aucun job en cours perdu (RabbitMQ persistant). |
| Incompatibilité ARM Graviton avec une extension Postgres | Aucune extension custom installée (vérifié via `SELECT extname FROM pg_extension;` = plpgsql + pg_stat_statements standards uniquement) |
| Coût mensuel inattendu | +15 $/mois plafonné, prédictible |

**Rollback** : remettre `db_instance_class = "db.t3.micro"` dans `tfvars`, `terraform apply`. Failover inverse, ~1-3 min.

## Vérifications post-déploiement

1. **Status instance** : `aws rds describe-db-instances --db-instance-identifier legalcase-production-postgres --query 'DBInstances[0].{class:DBInstanceClass,status:DBInstanceStatus}'`
   → Attendu : `class = "db.t4g.small"`, `status = "available"`
2. **CloudWatch CPU** sur 1 h post-upgrade : doit rester < 30 % en idle (vs. burst credits)
3. **Smoke test app** : `curl https://legalcase.fr/actuator/health` + lancer une analyse de dossier test (Dupont 7 PDF) — doit terminer en temps comparable ou meilleur
4. **Connexions actives** : `SELECT count(*) FROM pg_stat_activity;` < 30 (sain)

## Commit

Branche `feat/infra-rds-t4g-small` :
```
feat(rds): production upgrade db.t3.micro → db.t4g.small

- Bascule sur ARM Graviton2, 2 vCPU dédiés, 2 GB RAM
- Supprime le risque de throttling CPU credits sous charge IA
- Compatible Postgres 16.10, no extension custom
- Failover Multi-AZ ~1-3 min de downtime côté primaire
```
