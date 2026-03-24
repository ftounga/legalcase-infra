variable "project" {
  default = "legalcase"
}

variable "region" {
  default = "eu-west-3"
}

variable "vpc_cidr" {
  default = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  default = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "private_subnet_cidrs" {
  default = ["10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"]
}

variable "database_subnet_cidrs" {
  default = ["10.0.21.0/24", "10.0.22.0/24", "10.0.23.0/24"]
}

variable "kubernetes_version" {
  default = "1.31"
}

variable "node_instance_type" {
  default = "t3.medium"
}

variable "node_desired_size" {
  default = 2
}

variable "node_min_size" {
  default = 2
}

variable "node_max_size" {
  default = 4
}
