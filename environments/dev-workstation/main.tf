terraform {
  required_version = ">= 1.3.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    cloudinit = {
      source  = "hashicorp/cloudinit"
      version = "~> 2.3"
    }
  }

  backend "s3" {
    bucket         = "legalcase-terraform-state-504895205419"
    key            = "dev-workstation/terraform.tfstate"
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
  environment = "dev-workstation"
  common_tags = {
    Project     = var.project
    Environment = local.environment
    ManagedBy   = "terraform"
  }
}

# Lecture du VPC partagé créé par cluster/
data "terraform_remote_state" "cluster" {
  backend = "s3"
  config = {
    bucket  = "legalcase-terraform-state-504895205419"
    key     = "cluster/terraform.tfstate"
    region  = "eu-west-3"
    profile = "legalcase-terraform"
  }
}

# Découverte des subnets privés du cluster (tag kubernetes.io/role/internal-elb = 1)
data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.terraform_remote_state.cluster.outputs.vpc_id]
  }

  tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }
}

module "dev_workstation" {
  source = "../../modules/dev-workstation"

  project     = var.project
  environment = local.environment

  vpc_id    = data.terraform_remote_state.cluster.outputs.vpc_id
  subnet_id = data.aws_subnets.private.ids[0]

  instance_type  = var.instance_type
  git_user_name  = var.git_user_name
  git_user_email = var.git_user_email
  repos_to_clone = var.repos_to_clone

  tags = local.common_tags
}
