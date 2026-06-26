output "state_bucket" {
  description = "S3 bucket name for Terraform state — set as TF_STATE_BUCKET in GitHub vars"
  value       = aws_s3_bucket.state.id
}

output "state_lock_table" {
  description = "DynamoDB table for state locking — set as TF_STATE_LOCK_TABLE in GitHub vars"
  value       = aws_dynamodb_table.state_lock.name
}

output "plan_role_arn" {
  description = "IAM role ARN for CI plan jobs — set as TF_PLAN_ROLE_ARN in GitHub vars"
  value       = aws_iam_role.plan.arn
}

output "apply_role_arn" {
  description = "IAM role ARN for CI apply jobs — set as TF_APPLY_ROLE_ARN in GitHub vars"
  value       = aws_iam_role.apply.arn
}
