variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "name_prefix" {
  description = "Prefix for all resource names"
  type        = string
  default     = "infra102"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "sandbox"
}

variable "github_repo" {
  description = "GitHub repo in format owner/repo (e.g. Vuong-Bach/infra-102)"
  type        = string
}
