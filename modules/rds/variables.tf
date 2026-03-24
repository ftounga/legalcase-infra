variable "project" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name (staging, production)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "database_subnet_ids" {
  description = "IDs of database subnets"
  type        = list(string)
}

variable "eks_node_security_group_id" {
  description = "Security group ID of EKS worker nodes"
  type        = string
}

variable "db_name" {
  description = "Name of the initial database"
  type        = string
  default     = "legalcase"
}

variable "db_username" {
  description = "Master username for the database"
  type        = string
  default     = "legalcase_admin"
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "allocated_storage" {
  description = "Initial allocated storage in GB"
  type        = number
  default     = 20
}

variable "max_allocated_storage" {
  description = "Maximum storage for autoscaling in GB"
  type        = number
  default     = 100
}

variable "multi_az" {
  description = "Enable Multi-AZ deployment"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
