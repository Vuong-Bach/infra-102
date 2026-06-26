locals {
  azs = ["${var.aws_region}a", "${var.aws_region}b"]
  tags = {
    Project     = "infra102"
    Environment = "sandbox"
    ManagedBy   = "terraform"
    Layer       = "1-networking"
  }
}

module "networking" {
  source = "../../../modules/networking"

  name_prefix          = var.name_prefix
  azs                  = local.azs
  private_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnet_cidrs  = ["10.0.101.0/24", "10.0.102.0/24"]
  tags                 = local.tags
}

module "security" {
  source = "../../../modules/security"

  name_prefix = var.name_prefix
  vpc_id      = module.networking.vpc_id
  tags        = local.tags
}
