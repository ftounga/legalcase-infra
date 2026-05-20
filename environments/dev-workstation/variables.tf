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

variable "instance_type" {
  description = "EC2 instance type for the dev workstation"
  type        = string
  default     = "m7i.2xlarge"
}

variable "git_user_name" {
  description = "Value for git config user.name inside the instance"
  type        = string
}

variable "git_user_email" {
  description = "Value for git config user.email inside the instance"
  type        = string
}

variable "repos_to_clone" {
  description = "HTTPS repos automatically cloned into ~/dev by cloud-init"
  type        = list(string)
  default = [
    "https://github.com/ftounga/legalCase.git",
    "https://github.com/ftounga/legalcase-infra.git",
  ]
}
