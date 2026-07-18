variable "account_name" {
  description = "Logical name of the account this baseline is applied to (used in tags/descriptions)."
  type        = string
}

variable "enable_s3_account_public_access_block" {
  description = "Turn on the account-wide S3 Block Public Access. Safe default for every account."
  type        = bool
  default     = true
}

variable "enable_default_ebs_encryption" {
  description = "Enable EBS encryption by default in this account/region. Safe default; free."
  type        = bool
  default     = true
}

variable "tags" {
  description = <<-EOT
    Tags to apply to taggable baseline resources. The current baseline resources
    (account-wide S3 Block Public Access, default EBS encryption) are
    account-global toggles that are not taggable, so tags are held for future
    taggable additions and echoed via the `tags` output for callers to reuse.
  EOT
  type        = map(string)
  default     = {}
}

variable "remove_default_vpc" {
  description = <<-EOT
    Delete the region's default VPC (subnets -> internet gateway -> VPC) via a
    local-exec teardown script. Requires the AWS CLI on the machine running
    Terraform. Covers only `region`; run per region for full coverage.
  EOT
  type        = bool
  default     = false
}

variable "region" {
  description = "Region whose default VPC to delete (used by the teardown script). Should match the provider's region."
  type        = string
  default     = "us-east-1"
}

variable "exec_role_arn" {
  description = <<-EOT
    Optional role ARN the teardown script assumes before acting. REQUIRED when
    the provider assumes into a member account, because local-exec does not
    inherit the provider's credentials -- set it to the same role the provider
    uses (e.g. the account's OrganizationAccountAccessRole). Empty = ambient creds.
  EOT
  type        = string
  default     = ""
}
