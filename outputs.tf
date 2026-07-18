output "account_name" {
  description = "Logical name of the account this baseline was applied to."
  value       = var.account_name
}

output "tags" {
  description = "The tags passed to this baseline, for callers to reuse on account-level resources they add."
  value       = var.tags
}

output "s3_public_access_block_enabled" {
  description = "Whether the account-wide S3 Block Public Access was applied."
  value       = var.enable_s3_account_public_access_block
}

output "default_ebs_encryption_enabled" {
  description = "Whether default EBS encryption was enabled for this account/region."
  value       = var.enable_default_ebs_encryption
}
