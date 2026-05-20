# SF-INFRA-06 — Audit EBS snapshots (résultat : sain, rien à purger)

## Objectif

Vérifier qu'il n'y a pas de snapshots EBS orphelins ou redondants dans le compte AWS, et chiffrer leur coût mensuel.

## Contexte

Hypothèse initiale (avant audit) : présence possible de snapshots manuels créés pour des tests et jamais nettoyés, avec une économie attendue de $5-15/mois.

## Audit effectué le 2026-05-20

```bash
aws --profile legalcase-terraform ec2 describe-snapshots --owner-ids self --region eu-west-3
```

**Résultats** :
- **14 snapshots EBS au total**
- **Tous issus de AWS Backup service** (description `"This snapshot is created by the AWS Backup service."`)
- **2 volumes source** :
  - `vol-07f12e189d51f36a8` (5 GB) — PVC EBS CSI
  - `vol-05934547fe5072a25` (5 GB) — PVC `rabbitmq-data` (le bus de messages)
- **Distribution d'âge** :
  - 0 snapshot > 7 jours
  - Répartition équilibrée : 2 snapshots/jour × 7 j = 14 snapshots
- **Aucun snapshot manuel orphelin** créé hors AWS Backup.

## Conclusion

Le backup plan configuré dans `modules/backup/` (rétention 7 j, cf. `environments/production/main.tf`) **fonctionne comme prévu**. Les vieux snapshots sont automatiquement purgés.

### Coût réel

- Snapshots EBS facturés en **stockage incrémental** : le premier snapshot = taille pleine du volume, les suivants = delta uniquement.
- Pour des volumes RabbitMQ + PVC peu remplis : **~$0,50 à $1,00/mois pour les 14 snapshots cumulés**.
- `VolumeSize: 5 GB` rapporté par l'API est la taille du volume source, **pas** la consommation réelle du snapshot.

→ **Économie attendue initialement ($5-15/mois) basée sur une mauvaise compréhension**. L'économie réelle serait < $1/mois si on coupait les backups, ce qui n'est pas souhaitable.

## Décision

**Aucune action de purge nécessaire.** Le backup plan est sain et économique.

## Items de surveillance (pas d'action immédiate)

- Si un jour on voit le nombre de snapshots dépasser 16 (= 7 j × 2 vol + tolérance), c'est un signal que la rétention ou la fréquence a dérivé.
- Si un volume EBS supplémentaire est créé (nouveau PVC stateful par ex.), il sera automatiquement inclus dans le backup plan si tagué `BackupEnabled=true` (cf. `modules/backup/main.tf`).

## Documentation

Cette SF reste une **trace d'audit** dans le backlog, marquée comme `Appliquée — audit OK, rien à purger`.

## Commit

Branche `feat/infra-cleanup-logs-snapshots-audit` :
```
docs(snapshots): audit EBS snapshots — sain, rien à purger (SF-INFRA-06)
```
