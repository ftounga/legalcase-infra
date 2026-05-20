variable "project" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name (staging, production)"
  type        = string
}

variable "s3_bucket_id" {
  description = "ID (name) of the origin S3 bucket"
  type        = string
}

variable "s3_bucket_arn" {
  description = "ARN of the origin S3 bucket"
  type        = string
}

variable "s3_bucket_regional_domain_name" {
  description = "Regional domain name of the origin S3 bucket"
  type        = string
}

variable "price_class" {
  description = "CloudFront price class (PriceClass_100 = Europe + US/Canada, cheapest)"
  type        = string
  default     = "PriceClass_100"
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
