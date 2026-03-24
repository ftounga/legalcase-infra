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
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
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

module "networking" {
  source = "../../modules/networking"

  project     = var.project
  environment = local.environment
  region      = var.region
  vpc_cidr    = var.vpc_cidr

  public_subnet_cidrs   = var.public_subnet_cidrs
  private_subnet_cidrs  = var.private_subnet_cidrs
  database_subnet_cidrs = var.database_subnet_cidrs

  tags = local.common_tags
}

module "eks" {
  source = "../../modules/eks"

  project     = var.project
  environment = local.environment
  vpc_id      = module.networking.vpc_id

  private_subnet_ids = module.networking.private_subnet_ids
  public_subnet_ids  = module.networking.public_subnet_ids

  kubernetes_version = var.kubernetes_version
  node_instance_type = var.node_instance_type
  node_desired_size  = var.node_desired_size
  node_min_size      = var.node_min_size
  node_max_size      = var.node_max_size

  tags = local.common_tags
}

module "rds" {
  source = "../../modules/rds"

  project     = var.project
  environment = local.environment
  vpc_id      = module.networking.vpc_id

  database_subnet_ids        = module.networking.database_subnet_ids
  eks_node_security_group_id = module.eks.node_security_group_id

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

module "ecr" {
  source = "../../modules/ecr"

  project = var.project

  tags = local.common_tags
}
