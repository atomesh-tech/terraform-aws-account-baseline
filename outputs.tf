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

output "spoke_vpc_enabled" {
  description = "Whether the private spoke VPC was created in this account/region."
  value       = var.enable_spoke_vpc
}

output "spoke_vpc_id" {
  description = "ID of the private spoke VPC, or null when disabled."
  value       = one(aws_vpc.spoke[*].id)
}

output "spoke_vpc_primary_cidr" {
  description = "Primary IPv4 CIDR of the spoke VPC, or null when disabled."
  value       = one(aws_vpc.spoke[*].cidr_block)
}

output "spoke_vpc_secondary_cidrs" {
  description = "Secondary IPv4 CIDRs associated with the spoke VPC (sorted)."
  value       = sort([for a in aws_vpc_ipv4_cidr_block_association.spoke : a.cidr_block])
}

output "spoke_private_subnet_ids" {
  description = "Map of subnet key (\"<source-cidr>-<az>\") to private subnet ID. Consumed by the Pro TGW layer to attach the VPC."
  value       = { for k, s in aws_subnet.spoke_private : k => s.id }
}

output "spoke_private_route_table_ids" {
  description = "Map of subnet key to private route-table ID; the Pro TGW layer adds egress routes to these."
  value       = { for k, rt in aws_route_table.spoke_private : k => rt.id }
}

output "spoke_default_security_group_id" {
  description = "ID of the spoke VPC's locked (zero-rule) default security group, or null when disabled."
  value       = one(aws_default_security_group.spoke[*].id)
}
