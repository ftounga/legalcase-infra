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
