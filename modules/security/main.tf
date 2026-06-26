data "aws_caller_identity" "current" {}

# ── Security Groups ───────────────────────────────────────────────────────────
resource "aws_security_group" "eks_control_plane" {
  name        = "${var.name_prefix}-eks-control-plane"
  description = "EKS control plane ENI"
  vpc_id      = var.vpc_id
  tags        = merge(var.tags, { Name = "${var.name_prefix}-eks-control-plane" })
}

resource "aws_security_group" "eks_nodes" {
  name        = "${var.name_prefix}-eks-nodes"
  description = "EKS worker nodes"
  vpc_id      = var.vpc_id
  tags        = merge(var.tags, { Name = "${var.name_prefix}-eks-nodes" })
}

# Nodes: allow all traffic between nodes in the same SG
resource "aws_security_group_rule" "nodes_self_ingress" {
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  self              = true
  security_group_id = aws_security_group.eks_nodes.id
  description       = "Node-to-node traffic"
}

# Nodes: allow kubelet + NodePort range from control plane
resource "aws_security_group_rule" "nodes_from_control_plane" {
  type                     = "ingress"
  from_port                = 1025
  to_port                  = 65535
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks_nodes.id
  source_security_group_id = aws_security_group.eks_control_plane.id
  description              = "Control plane to kubelet/NodePort"
}

# Nodes: allow all outbound (NAT GW handles egress to internet/ECR)
resource "aws_security_group_rule" "nodes_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.eks_nodes.id
  description       = "All outbound"
}

# Control plane: allow HTTPS from nodes (kubectl exec, metrics)
resource "aws_security_group_rule" "control_plane_from_nodes" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks_control_plane.id
  source_security_group_id = aws_security_group.eks_nodes.id
  description              = "Nodes to API server"
}

# Control plane: outbound to kubelet
resource "aws_security_group_rule" "control_plane_to_nodes" {
  type                     = "egress"
  from_port                = 1025
  to_port                  = 65535
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks_control_plane.id
  source_security_group_id = aws_security_group.eks_nodes.id
  description              = "API server to kubelet"
}

# ── KMS Key for EKS secrets encryption ───────────────────────────────────────
resource "aws_kms_key" "eks" {
  description             = "EKS secrets encryption — ${var.name_prefix}"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "Root"
      Effect    = "Allow"
      Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
      Action    = "kms:*"
      Resource  = "*"
    }]
  })
  tags = merge(var.tags, { Name = "${var.name_prefix}-eks-kms" })
}

resource "aws_kms_alias" "eks" {
  name          = "alias/${var.name_prefix}-eks"
  target_key_id = aws_kms_key.eks.key_id
}
