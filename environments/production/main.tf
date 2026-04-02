terraform {
  required_version = ">= 1.3.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }

  backend "s3" {
    bucket         = "legalcase-terraform-state-504895205419"
    key            = "production/terraform.tfstate"
    region         = "eu-west-3"
    profile        = "legalcase-terraform"
    dynamodb_table = "legalcase-terraform-lock"
    encrypt        = true
  }
}

provider "aws" {
  region  = var.region
  profile = "legalcase-terraform"

  default_tags {
    tags = local.common_tags
  }
}

locals {
  environment = "production"
  common_tags = {
    Project     = var.project
    Environment = local.environment
    ManagedBy   = "terraform"
  }
}

data "aws_caller_identity" "current" {}

# Lecture des outputs du cluster partagé
data "terraform_remote_state" "cluster" {
  backend = "s3"
  config = {
    bucket  = "legalcase-terraform-state-504895205419"
    key     = "cluster/terraform.tfstate"
    region  = "eu-west-3"
    profile = "legalcase-terraform"
  }
}

module "rds" {
  source = "../../modules/rds"

  project     = var.project
  environment = local.environment
  vpc_id      = data.terraform_remote_state.cluster.outputs.vpc_id

  database_subnet_ids        = data.terraform_remote_state.cluster.outputs.database_subnet_ids
  eks_node_security_group_id = data.terraform_remote_state.cluster.outputs.node_security_group_id

  db_instance_class     = var.db_instance_class
  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = var.db_max_allocated_storage
  multi_az              = true

  tags = local.common_tags
}

module "s3" {
  source = "../../modules/s3"

  project     = var.project
  environment = local.environment
  account_id  = data.aws_caller_identity.current.account_id

  allowed_origins = var.s3_allowed_origins

  tags = local.common_tags
}

module "backup" {
  source = "../../modules/backup"

  project               = var.project
  environment           = local.environment
  backup_retention_days = 7

  tags = local.common_tags
}

# ─── Backend IRSA — accès S3 documents ───────────────────────────────────────
data "aws_eks_cluster" "main" {
  name = data.terraform_remote_state.cluster.outputs.eks_cluster_name
}

data "aws_iam_openid_connect_provider" "eks" {
  url = data.aws_eks_cluster.main.identity[0].oidc[0].issuer
}

locals {
  oidc_issuer = replace(data.aws_iam_openid_connect_provider.eks.url, "https://", "")
  s3_bucket_arn = "arn:aws:s3:::${var.project}-${local.environment}-documents-${data.aws_caller_identity.current.account_id}"
}

data "aws_iam_policy_document" "backend_irsa_assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.eks.arn]
    }
    actions = ["sts:AssumeRoleWithWebIdentity"]
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer}:sub"
      values   = ["system:serviceaccount:${local.environment}:legalcase-backend"]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "backend_irsa" {
  name               = "${var.project}-backend-${local.environment}-s3-role"
  assume_role_policy = data.aws_iam_policy_document.backend_irsa_assume_role.json
  tags               = local.common_tags
}

resource "aws_iam_role_policy" "backend_s3" {
  name = "${var.project}-backend-${local.environment}-s3-policy"
  role = aws_iam_role.backend_irsa.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket",
      ]
      Resource = [
        local.s3_bucket_arn,
        "${local.s3_bucket_arn}/*",
      ]
    }]
  })
}

output "irsa_backend_role_arn" {
  description = "ARN of the IAM role for backend S3 access via IRSA"
  value       = aws_iam_role.backend_irsa.arn
}
