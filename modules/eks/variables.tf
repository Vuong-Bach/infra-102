variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "cluster_version" {
  description = "EKS Kubernetes version"
  type        = string
  default     = "1.30"
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for EKS nodes"
  type        = list(string)
}

variable "sg_eks_control_plane_id" {
  description = "Security group ID for EKS control plane"
  type        = string
}

variable "sg_eks_nodes_id" {
  description = "Security group ID for EKS worker nodes"
  type        = string
}

variable "kms_eks_arn" {
  description = "KMS key ARN for EKS secrets encryption"
  type        = string
}

variable "node_instance_types" {
  description = "EC2 instance types for the managed node group"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_desired_size" {
  description = "Desired number of nodes"
  type        = number
  default     = 1
}

variable "node_min_size" {
  description = "Minimum number of nodes"
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "Maximum number of nodes"
  type        = number
  default     = 3
}

variable "tags" {
  description = "Tags applied to every resource"
  type        = map(string)
  default     = {}
}
