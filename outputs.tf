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

output "iam_account_password_policy_enabled" {
  description = "Whether the account IAM password policy was managed by this baseline."
  value       = var.enable_iam_account_password_policy
}

output "account_alias" {
  description = "The IAM account alias set for this account, or null when not managed."
  value       = one(aws_iam_account_alias.this[*].account_alias)
}

output "default_security_group_restricted" {
  description = "Whether default-SG lockdown (CIS v3.0.0 5.4) is enabled for this apply."
  value       = var.restrict_default_security_group
}

output "restricted_default_security_group_vpc_ids" {
  description = "VPC IDs whose default security group this baseline locked to zero rules (provider-region default VPC plus any explicitly opted-in)."
  value       = sort(tolist(local.restricted_default_sg_vpc_ids))
}

output "account_access_analyzer_arn" {
  description = "ARN of the ACCOUNT (external-access) Access Analyzer for this account/region, or null when disabled."
  value       = one(aws_accessanalyzer_analyzer.account[*].arn)
}

output "account_access_analyzer_enabled" {
  description = "Whether the ACCOUNT (external-access) Access Analyzer was actually created in this account/region."
  value       = length(aws_accessanalyzer_analyzer.account) > 0
}

output "default_ebs_encryption_cmk_enabled" {
  description = "Whether default EBS encryption uses a customer-managed KMS key (CMK) in this account/region."
  value       = var.enable_default_ebs_encryption_cmk
}

output "default_ebs_encryption_cmk_arn" {
  description = "ARN of the customer-managed EBS default KMS key, or null when disabled."
  value       = one(aws_kms_key.ebs_default[*].arn)
}

output "default_ebs_encryption_cmk_alias" {
  description = "Alias of the customer-managed EBS default KMS key, or null when disabled."
  value       = one(aws_kms_alias.ebs_default[*].name)
}

output "imdsv2_account_default_enabled" {
  description = "Whether the account+region IMDS default was set to require IMDSv2 for new launches (CIS-ALIGNED v3.0.0 5.6, preventive-config complement)."
  value       = var.enable_imdsv2_account_default
}

output "notifications_topic_arn" {
  description = "ARN of the account notifications SNS topic (the publish seam), or null when disabled. Wire future budget/alarm/security features to this."
  value       = one(aws_sns_topic.notifications[*].arn)
}

output "notifications_topic_name" {
  description = "Name of the account notifications SNS topic, or null when disabled."
  value       = one(aws_sns_topic.notifications[*].name)
}
