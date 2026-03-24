variable "project" {
  description = "Project name used as prefix for all resources"
  type        = string
  default     = "legalcase"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-3"
}
