# Infra Afrique OHADA — specs HYPOTHÈSE (GELÉES)

> ⚠️ **STATUT : HYPOTHÈSE / GELÉ — observation passive. NE PAS APPLIQUER.**
> Ces specs préparent le provisioning de l'instance régionale **Afrique (`af-south-1`)** de LegalCase
> pour le marché OHADA. Elles existent pour rendre l'engagement **mécanique le jour venu**, mais
> **rien ne doit être provisionné** tant que le verrou d'activation n'est pas levé.
>
> **Verrou** (cf. `legalCase` → `docs/radar-cameroun-ohada.md` + `docs/afrique/CADRAGE-STRATEGIQUE-OHADA.md`) :
> 30 K€ MRR FR/BE en bootstrap, OU substitution (capital fléché Afrique + ≥ 3 intentions de paiement OHADA).
> Coût réel **0 $ tant que non appliqué**. Aucune entrée dans le `BACKLOG_INFRA.md` actif (eu-west-3).

## Contexte

Décision produit (repo `legalCase`, cadrage `docs/afrique/CADRAGE-STRATEGIQUE-OHADA.md`) :
- **D1** : même application / même codebase ; la séparation est au niveau **instance déployée**.
- **D9** : résidence des données en Afrique **obligatoire** (loi CM n°2024/017, conformité 23/06/2026) →
  région `af-south-1` (Cape Town) ou OVH Africa, **distincte** d'`eu-west-3`.
- **D10** : domaines `legalcase.africa` (prod) + `staging.legalcase.africa` (staging).
- **§3.1/§3.2** : un **seul cluster EKS** régional, `staging` + `production` en **namespaces** ;
  **réutilisation des modules Terraform existants** (`networking`, `eks`, `rds`, `s3`, `cdn`, `ecr`,
  `monitoring`, `backup`) → l'effort est de la **configuration régionale**, pas du développement.

## Principe d'exécution (le jour de l'engagement)

1. Lever le gel (verrou levé, décision PO explicite).
2. Appliquer les SF-INFRA-AF dans l'ordre des dépendances (01 → 07).
3. Puis déployer l'app et lancer le dev des features `F-OH-…` livrées par le workflow
   `afrique-product-spec` (repo `legalCase`).

## Specs

| ID | Objet | Module(s) | Dépend de |
|----|-------|-----------|-----------|
| [SF-INFRA-AF-01](SF-INFRA-AF-01-networking.md) | Networking `af-south-1` (VPC, subnets, NAT, IGW) | `networking` | — |
| [SF-INFRA-AF-02](SF-INFRA-AF-02-eks-cluster.md) | Cluster EKS Afrique + namespaces `staging`/`production` | `eks` | AF-01 |
| [SF-INFRA-AF-03](SF-INFRA-AF-03-rds.md) | RDS PostgreSQL régional (résidence données) | `rds` | AF-01 |
| [SF-INFRA-AF-04](SF-INFRA-AF-04-s3-backups.md) | S3 documents + backups régionaux | `s3`, `backup` | AF-01 |
| [SF-INFRA-AF-05](SF-INFRA-AF-05-cloudfront-acm-domains.md) | CloudFront + ACM, domaines `legalcase.africa` | `cdn` | AF-04 |
| [SF-INFRA-AF-06](SF-INFRA-AF-06-ecr-secrets.md) | ECR images + Secrets Manager régional | `ecr` | AF-01 |
| [SF-INFRA-AF-07](SF-INFRA-AF-07-monitoring-logs.md) | Monitoring + logs CloudWatch régionaux | `monitoring` | AF-02, AF-03 |

## Hors de ces specs (= features produit, repo `legalCase`)

Paiement (CinetPay / mobile money), devise XOF/XAF, i18n, contexte-pays, consentement résidence côté UX :
ce sont des **features produit** (`F-OH-…`), pas de l'infra. Voir la fiche produit `legalCase/docs/afrique/`.
