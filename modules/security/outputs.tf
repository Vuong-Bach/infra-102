output "sg_eks_control_plane_id" {
  description = "Security group ID for EKS control plane"
  value       = aws_security_group.eks_control_plane.id
}

output "sg_eks_nodes_id" {
  description = "Security group ID for EKS worker nodes"
  value       = aws_security_group.eks_nodes.id
}

output "kms_eks_arn" {
  description = "KMS key ARN for EKS secrets encryption"
  value       = aws_kms_key.eks.arn
}
