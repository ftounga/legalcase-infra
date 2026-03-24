#!/usr/bin/env python3
"""
LegalCase — AWS Architecture Diagrams
Génère deux diagrammes PNG (staging + production).

Prérequis :
    sudo apt install graphviz
    pip install diagrams

Usage :
    cd docs/
    python3 generate_diagrams.py
"""

from pathlib import Path

from diagrams import Cluster, Diagram, Edge
from diagrams.aws.compute import EC2, ECR, EKS
from diagrams.aws.database import RDS
from diagrams.aws.network import InternetGateway, NATGateway
from diagrams.aws.security import SecretsManager
from diagrams.aws.storage import S3
from diagrams.onprem.client import Users

OUTPUT_DIR = Path(__file__).parent / "diagrams"
OUTPUT_DIR.mkdir(exist_ok=True)

GRAPH_ATTR = {
    "fontsize": "13",
    "bgcolor": "white",
    "pad": "0.8",
    "splines": "ortho",
    "nodesep": "0.6",
    "ranksep": "0.8",
}

NODE_ATTR = {
    "fontsize": "11",
}


def make_env_diagram(
    env: str,
    vpc_cidr: str,
    node_count: int,
    multi_az: bool,
) -> None:
    output_file = str(OUTPUT_DIR / f"legalcase_{env}")
    title = f"LegalCase — Infrastructure AWS  |  {env.upper()}  |  eu-west-3 (Paris)"

    with Diagram(
        title,
        filename=output_file,
        show=False,
        direction="LR",
        graph_attr=GRAPH_ATTR,
        node_attr=NODE_ATTR,
    ):
        users = Users("Utilisateurs")

        # ── Services AWS globaux (hors VPC) ──────────────────────────────────
        with Cluster("Services globaux AWS"):
            ecr_be = ECR("ECR\nlegalcase-backend")
            ecr_fe = ECR("ECR\nlegalcase-frontend")
            s3_docs = S3(f"S3 Documents\nlegalcase-{env}")
            secrets = SecretsManager("Secrets Manager\nRDS credentials")

        # ── VPC ──────────────────────────────────────────────────────────────
        with Cluster(f"VPC  legalcase-{env}  —  {vpc_cidr}\n3 AZs : eu-west-3a/b/c"):

            # Public subnets
            with Cluster("Subnets publics  (10.x.1-3.0/24)"):
                igw = InternetGateway("Internet\nGateway")
                nat = NATGateway("NAT Gateway\n(Single, AZ-a)")

            # Private subnets — EKS
            with Cluster("Subnets privés  (10.x.10-12.0/24)"):
                eks = EKS(f"EKS Cluster  v1.31\nlegalcase-{env}")
                nodes = [
                    EC2(f"Node {i + 1}\nt3.medium")
                    for i in range(node_count)
                ]

            # Database subnets
            with Cluster("Subnets database  (10.x.20-22.0/24)"):
                rds_label = (
                    "PostgreSQL 16\ndb.t3.micro\nMulti-AZ ✓"
                    if multi_az
                    else "PostgreSQL 16\ndb.t3.micro\nSingle-AZ"
                )
                rds = RDS(rds_label)

        # ── Connexions ────────────────────────────────────────────────────────
        users >> Edge(label="HTTPS") >> igw
        igw >> Edge(color="darkorange") >> nat
        igw >> Edge(label="ingress") >> eks
        nat >> Edge(label="egress") >> eks

        eks >> Edge(label="manage") >> nodes
        nodes >> Edge(label="5432") >> rds
        nodes >> Edge(color="darkgreen") >> secrets
        nodes >> Edge(color="darkgreen") >> s3_docs

        # Pull images depuis ECR
        eks >> Edge(label="pull", style="dashed", color="steelblue") >> ecr_be
        eks >> Edge(label="pull", style="dashed", color="steelblue") >> ecr_fe

    print(f"✓  {output_file}.png")


def make_global_diagram() -> None:
    """Diagramme vue globale : les deux environnements + ressources partagées."""
    output_file = str(OUTPUT_DIR / "legalcase_overview")

    with Diagram(
        "LegalCase — Vue d'ensemble  |  AWS eu-west-3",
        filename=output_file,
        show=False,
        direction="TB",
        graph_attr={**GRAPH_ATTR, "ranksep": "1.2"},
        node_attr=NODE_ATTR,
    ):
        users = Users("Utilisateurs")

        # Ressources partagées
        with Cluster("Ressources partagées (global)"):
            ecr_be = ECR("ECR Backend")
            ecr_fe = ECR("ECR Frontend")
            s3_state = S3("S3 Terraform\nState")

        # Staging
        with Cluster("Staging  —  VPC 10.0.0.0/16"):
            igw_stg = InternetGateway("IGW")
            nat_stg = NATGateway("NAT GW")
            eks_stg = EKS("EKS 1.31\n1 × t3.medium")
            rds_stg = RDS("PostgreSQL 16\nSingle-AZ")
            s3_stg = S3("S3 Documents\nstaging")
            sec_stg = SecretsManager("Secrets")

        # Production
        with Cluster("Production  —  VPC 10.1.0.0/16"):
            igw_prd = InternetGateway("IGW")
            nat_prd = NATGateway("NAT GW")
            eks_prd = EKS("EKS 1.31\n2 × t3.medium")
            rds_prd = RDS("PostgreSQL 16\nMulti-AZ ✓")
            s3_prd = S3("S3 Documents\nproduction")
            sec_prd = SecretsManager("Secrets")

        # Connexions staging
        users >> igw_stg >> nat_stg
        igw_stg >> eks_stg >> rds_stg
        eks_stg >> s3_stg
        eks_stg >> sec_stg
        eks_stg >> Edge(style="dashed") >> ecr_be
        eks_stg >> Edge(style="dashed") >> ecr_fe

        # Connexions production
        users >> igw_prd >> nat_prd
        igw_prd >> eks_prd >> rds_prd
        eks_prd >> s3_prd
        eks_prd >> sec_prd
        eks_prd >> Edge(style="dashed") >> ecr_be
        eks_prd >> Edge(style="dashed") >> ecr_fe

    print(f"✓  {output_file}.png")


if __name__ == "__main__":
    print("Génération des diagrammes LegalCase...\n")

    make_env_diagram(
        env="staging",
        vpc_cidr="10.0.0.0/16",
        node_count=1,
        multi_az=False,
    )
    make_env_diagram(
        env="production",
        vpc_cidr="10.1.0.0/16",
        node_count=2,
        multi_az=True,
    )
    make_global_diagram()

    print(f"\nDiagrammes générés dans : docs/diagrams/")
    print("  • legalcase_staging.png")
    print("  • legalcase_production.png")
    print("  • legalcase_overview.png")
