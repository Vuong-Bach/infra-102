# Partial backend config — pass values via -backend-config flags or env vars.
# See README.md § Local Development for the full terraform init command.
terraform {
  backend "s3" {}
}
