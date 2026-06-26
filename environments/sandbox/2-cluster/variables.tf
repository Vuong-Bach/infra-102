variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "name_prefix" {
  description = "Resource name prefix"
  type        = string
  default     = "infra102-sandbox"
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.30"
}

variable "tf_state_bucket" {
  description = "S3 bucket holding Terraform state (output from bootstrap)"
  type        = string
}

variable "tf_state_region" {
  description = "Region of the Terraform state bucket"
  type        = string
  default     = "us-east-1"
}
