output "vpc_id" {
  value = module.networking.vpc_id
}

output "vpc_cidr" {
  value = module.networking.vpc_cidr
}

output "private_subnet_ids" {
  value = module.networking.private_subnet_ids
}

output "public_subnet_ids" {
  value = module.networking.public_subnet_ids
}

output "sg_eks_control_plane_id" {
  value = module.security.sg_eks_control_plane_id
}

output "sg_eks_nodes_id" {
  value = module.security.sg_eks_nodes_id
}

output "kms_eks_arn" {
  value = module.security.kms_eks_arn
}
