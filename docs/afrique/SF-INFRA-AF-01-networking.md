# SF-INFRA-AF-01 — Networking `af-south-1` (VPC régional Afrique)

> ⚠️ **HYPOTHÈSE / GELÉ — observation passive. NE PAS APPLIQUER.** Gate : voir `docs/afrique/README.md`.

## Objectif

Provisionner le socle réseau de l'instance régionale Afrique dans `af-south-1` (Cape Town), distinct et
isolé du réseau `eu-west-3` (Europe), pour héberger le cluster EKS, RDS et S3 régionaux conformément à
l'exigence de résidence des données (D9).

## Contexte

- **Région** : `af-south-1`. La résidence des données OHADA interdit de router ces workspaces vers l'Europe.
- **Réutilise le module existant `modules/networking/`** (VPC, subnets publics/privés multi-AZ, NAT Gateway,
  IGW, route tables) — aucune écriture de module, uniquement un nouvel appel paramétré sur la région.
- `af-south-1` expose 3 AZ (`af-south-1a/b/c`) → parité avec le schéma multi-AZ d'`eu-west-3`.

## Changements Terraform

Nouvel environnement régional : `environments/production-afrique/` (le staging Afrique partage le réseau et
le cluster via namespaces — cf. AF-02). `main.tf` instancie `modules/networking` :

```hcl
module "networking" {
  source             = "../../modules/networking"
  region             = "af-south-1"
  vpc_cidr           = "10.20.0.0/16"        # plage distincte d'eu-west-3 (à confirmer, non chevauchante)
  availability_zones = ["af-south-1a", "af-south-1b", "af-south-1c"]
  environment        = "afrique"
  # NAT single-AZ au démarrage (coût) ; passer multi-AZ à la montée en charge
}
```

> ⚠️ `af-south-1` est une région **opt-in** : activer la région sur le compte AWS (`aws account enable-region`)
> avant tout `plan`. Le provider AWS doit cibler `af-south-1` (alias provider ou backend dédié).

## Plan d'application

```bash
# Prérequis : région af-south-1 activée sur le compte ; backend state régional créé
cd environments/production-afrique
terraform init
terraform plan -out=tfplan-af-net   # revue : VPC + subnets + NAT + IGW + routes, aucune autre ressource
terraform apply tfplan-af-net
```

## Coût delta (indicatif)

| Composant | Coût /mois |
|-----------|-----------|
| NAT Gateway (single-AZ) | ~32 $ + trafic |
| VPC / subnets / IGW / route tables | 0 $ |

## Risques & rollback

| Risque | Mitigation |
|--------|-----------|
| Région opt-in non activée → `plan` échoue | Activer `af-south-1` au préalable (étape prérequis) |
| Chevauchement CIDR avec eu-west-3 (futur peering) | Choisir `10.20.0.0/16` non chevauchant dès le départ |
| Tarifs `af-south-1` ~15-20 % > eu-west-3 | Intégré au dossier de finançabilité (cadrage §3.1) |
