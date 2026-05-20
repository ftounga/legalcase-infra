variable "project" {
  description = "Project name used as prefix for all resources"
  type        = string
}

variable "environment" {
  description = "Environment name (e.g. dev-workstation)"
  type        = string
}

variable "vpc_id" {
  description = "VPC where the dev workstation will run"
  type        = string
}

variable "subnet_id" {
  description = "Private subnet id (with NAT egress) where the EC2 instance is launched"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "m7i.2xlarge"
}

variable "ebs_volume_size" {
  description = "Root EBS volume size in GiB"
  type        = number
  default     = 100
}

variable "ebs_volume_type" {
  description = "Root EBS volume type"
  type        = string
  default     = "gp3"
}

variable "linux_user" {
  description = "Linux user that owns the dev environment (cloud-init clones repos, installs Claude Code under this user)"
  type        = string
  default     = "ubuntu"
}

variable "git_user_name" {
  description = "Value for `git config user.name` inside the instance"
  type        = string
}

variable "git_user_email" {
  description = "Value for `git config user.email` inside the instance"
  type        = string
}

variable "repos_to_clone" {
  description = "List of HTTPS repo URLs that cloud-init will clone into ~/dev"
  type        = list(string)
  default     = []
}

variable "aws_cli_profile" {
  description = "Name of the AWS CLI profile to create inside the instance, sourcing credentials from the EC2 instance metadata (IMDS). Should match the profile referenced by the Terraform backend (`legalcase-terraform`)."
  type        = string
  default     = "legalcase-terraform"
}

variable "auto_stop_cron" {
  description = "EventBridge Scheduler cron expression for auto-stopping the instance. Timezone is Europe/Paris (DST handled by AWS). Default = 22:00 Paris every day."
  type        = string
  default     = "cron(0 22 * * ? *)"
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
