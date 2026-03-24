terraform {
  required_version = ">= 1.3.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  backend "s3" {
    bucket         = "legalcase-terraform-state-504895205419"
    key            = "cluster/terraform.tfstate"
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
    tags = {
      Project   = var.project
      ManagedBy = "terraform"
    }
  }
}

data "aws_caller_identity" "current" {}

module "networking" {
  source = "../modules/networking"

  project     = var.project
  environment = "shared"
  region      = var.region
  vpc_cidr    = var.vpc_cidr

  public_subnet_cidrs   = var.public_subnet_cidrs
  private_subnet_cidrs  = var.private_subnet_cidrs
  database_subnet_cidrs = var.database_subnet_cidrs

  tags = { Project = var.project, ManagedBy = "terraform" }
}

module "eks" {
  source = "../modules/eks"

  project     = var.project
  environment = "shared"
  vpc_id      = module.networking.vpc_id

  private_subnet_ids = module.networking.private_subnet_ids
  public_subnet_ids  = module.networking.public_subnet_ids

  kubernetes_version = var.kubernetes_version
  node_instance_type = var.node_instance_type
  node_desired_size  = var.node_desired_size
  node_min_size      = var.node_min_size
  node_max_size      = var.node_max_size

  tags = { Project = var.project, ManagedBy = "terraform" }
}

module "ecr" {
  source = "../modules/ecr"

  project = var.project

  tags = { Project = var.project, ManagedBy = "terraform" }
}
