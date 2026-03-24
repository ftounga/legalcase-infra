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
    key            = "staging/terraform.tfstate"
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
  environment = "staging"
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
  multi_az              = false

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

# Rôle IRSA pour le backend — accès S3 via le service account K8s
locals {
  oidc_issuer = replace(data.terraform_remote_state.cluster.outputs.oidc_issuer_url, "https://", "")
}

resource "aws_iam_role" "backend_irsa" {
  name = "${var.project}-backend-${local.environment}-s3-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = data.terraform_remote_state.cluster.outputs.oidc_provider_arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${local.oidc_issuer}:sub" = "system:serviceaccount:${local.environment}:${var.project}-backend"
          "${local.oidc_issuer}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })

  tags = local.common_tags
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
        "s3:ListBucket"
      ]
      Resource = [
        "arn:aws:s3:::${module.s3.bucket_id}",
        "arn:aws:s3:::${module.s3.bucket_id}/*"
      ]
    }]
  })
}
