variable "project" {
  description = "Project name"
  type        = string
  default     = "legalcase"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-3"
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.small"
}

variable "db_allocated_storage" {
  description = "Initial RDS allocated storage in GB"
  type        = number
  default     = 50
}

variable "db_max_allocated_storage" {
  description = "Maximum RDS storage for autoscaling in GB"
  type        = number
  default     = 200
}

variable "s3_allowed_origins" {
  description = "Allowed CORS origins for the documents S3 bucket"
  type        = list(string)
  default     = ["https://legalcase.ng-itconsulting.com"]
}
