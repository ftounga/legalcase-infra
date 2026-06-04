# SF-INFRA-AF-02 — Cluster EKS Afrique + namespaces `staging`/`production`

> ⚠️ **HYPOTHÈSE / GELÉ — observation passive. NE PAS APPLIQUER.** Gate : voir `docs/afrique/README.md`.

## Objectif

Provisionner **un seul cluster EKS** dans `af-south-1`, hébergeant les deux environnements applicatifs
**`staging` et `production` en namespaces** (même pattern que l'EKS partagé `eu-west-3`). Pas deux clusters.

## Contexte

- **Réutilise `modules/eks/`** (cluster + node group + IAM roles + IRSA). Config régionale uniquement.
- Dépend de **AF-01** (VPC/subnets régionaux).
- Séparation `staging`/`production` au niveau **namespace Kubernetes** + quotas, pas au niveau cluster
  (cohérent avec l'architecture `cluster/` partagée actuelle).

## Changements Terraform

Dans `environments/production-afrique/main.tf` :

```hcl
module "eks" {
  source          = "../../modules/eks"
  region          = "af-south-1"
  cluster_name    = "legalcase-afrique"
  cluster_version = "1.34"                        # parité avec eu-west-3
  vpc_id          = module.networking.vpc_id
  private_subnets = module.networking.private_subnet_ids
  node_instance_type = "t3.medium"               # démarrage ; ajuster selon charge
  node_min = 2
  node_max = 4
}
```

Namespaces applicatifs (`staging`, `production`) créés côté manifests K8s (repo `legalCase`, `k8s/`), pas ici.

## Plan d'application

```bash
cd environments/production-afrique
terraform plan -out=tfplan-af-eks   # revue : EKS control plane + node group + IAM/IRSA
terraform apply tfplan-af-eks
aws eks update-kubeconfig --name legalcase-afrique --region af-south-1
kubectl create namespace staging && kubectl create namespace production
```

## Coût delta (indicatif)

| Composant | Coût /mois |
|-----------|-----------|
| Control plane EKS | ~73 $ |
| Node group 2× t3.medium | ~60-70 $ |

## Risques & rollback

| Risque | Mitigation |
|--------|-----------|
| Types d'instance limités en `af-south-1` | Vérifier la dispo `t3.medium`/`m5` dans la région avant apply |
| Quotas EKS/EC2 régionaux à zéro | Demander une augmentation de quota en amont |
| Dérive de version vs eu-west-3 | Figer `cluster_version = 1.34` (parité), aligner les upgrades |
