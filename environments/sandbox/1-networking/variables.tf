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
