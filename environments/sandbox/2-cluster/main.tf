locals {
  tags = {
    Project     = "infra102"
    Environment = "sandbox"
    ManagedBy   = "terraform"
    Layer       = "2-cluster"
  }
}

module "eks" {
  source = "../../../modules/eks"

  name_prefix             = var.name_prefix
  cluster_version         = var.cluster_version
  vpc_id                  = data.terraform_remote_state.networking.outputs.vpc_id
  private_subnet_ids      = data.terraform_remote_state.networking.outputs.private_subnet_ids
  sg_eks_control_plane_id = data.terraform_remote_state.networking.outputs.sg_eks_control_plane_id
  sg_eks_nodes_id         = data.terraform_remote_state.networking.outputs.sg_eks_nodes_id
  kms_eks_arn             = data.terraform_remote_state.networking.outputs.kms_eks_arn
  node_desired_size       = 1
  node_min_size           = 1
  node_max_size           = 3
  tags                    = local.tags
}
