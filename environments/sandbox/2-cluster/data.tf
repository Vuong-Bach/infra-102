# Read outputs from Layer 1 (networking + security)
data "terraform_remote_state" "networking" {
  backend = "s3"
  config = {
    bucket = var.tf_state_bucket
    key    = "sandbox/1-networking/terraform.tfstate"
    region = var.tf_state_region
  }
}
