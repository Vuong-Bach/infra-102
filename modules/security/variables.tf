variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID (from networking module output)"
  type        = string
}

variable "tags" {
  description = "Tags applied to every resource"
  type        = map(string)
  default     = {}
}
