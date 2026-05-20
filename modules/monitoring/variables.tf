variable "project" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name (staging, production)"
  type        = string
}

variable "alert_email" {
  description = "Email address that will receive CloudWatch alarms"
  type        = string
}

variable "rds_instance_id" {
  description = "Identifier of the RDS instance to monitor"
  type        = string
}

variable "rds_cpu_threshold" {
  description = "CPU utilization percentage above which the RDS alarm fires"
  type        = number
  default     = 80
}

variable "rds_connections_threshold" {
  description = "Number of active DB connections above which the alarm fires"
  type        = number
  default     = 100
}

variable "rds_free_memory_bytes_threshold" {
  description = "FreeableMemory below this (in bytes) triggers an alarm. Default 200 MB."
  type        = number
  default     = 209715200
}

variable "enable_budget" {
  description = "Whether to provision an AWS Budgets monthly alert. Only one env should set this to true to avoid duplicate budgets in the same account."
  type        = bool
  default     = false
}

variable "enable_backend_error_alarm" {
  description = "Provision the backend ERROR rate alarm (requires Fluent Bit shipping application logs to the LegalCase/Application namespace)"
  type        = bool
  default     = false
}

variable "backend_error_rate_threshold" {
  description = "Number of backend ERROR log lines per 5 minutes above which the alarm fires"
  type        = number
  default     = 10
}

variable "monthly_budget_usd" {
  description = "Monthly budget in USD. Notifications fire at 80% (forecasted) and 100% (actual)."
  type        = number
  default     = 500
}

variable "tags" {
  description = "Tags applied to all resources"
  type        = map(string)
  default     = {}
}
