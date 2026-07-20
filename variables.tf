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

# ── IAM account password policy — CIS v3.0.0 1.8 + 1.9 ───────────────────────

variable "enable_iam_account_password_policy" {
  description = <<-EOT
    Manage the account's IAM password policy (singleton, account-global).
    Defaults are CIS AWS Foundations Benchmark v3.0.0-aligned (min length 14 +
    prevent reuse of 24). Affects only IAM users with console passwords -- not
    the root user and not IAM Identity Center/SSO users. Existing passwords are
    grandfathered, so enabling this does not lock out current users. WARNING:
    create = PutAccountPasswordPolicy REPLACES any existing account policy; set
    false on SSO-only accounts or where the policy is owned by another tool.
  EOT
  type        = bool
  default     = true
}

variable "password_minimum_length" {
  description = "Minimum IAM user password length. CIS v3.0.0 control 1.8 requires >= 14; a value below 14 forfeits 1.8 alignment."
  type        = number
  default     = 14
  validation {
    condition     = var.password_minimum_length >= 6 && var.password_minimum_length <= 128
    error_message = "password_minimum_length must be between 6 and 128 (AWS limits)."
  }
}

variable "password_reuse_prevention" {
  description = "Number of previous passwords IAM users may not reuse. CIS v3.0.0 control 1.9; 24 is the AWS maximum. 0 omits the setting."
  type        = number
  default     = 24
  validation {
    condition     = var.password_reuse_prevention >= 0 && var.password_reuse_prevention <= 24
    error_message = "password_reuse_prevention must be between 0 and 24 (0 = omit; 24 = AWS max)."
  }
}

variable "password_allow_users_to_change" {
  description = "Allow IAM users to change their own password. SAFETY: keep true so users can self-service rotate and are never locked out of a reset."
  type        = bool
  default     = true
}

variable "password_require_lowercase" {
  description = "Require >= 1 lowercase letter. REMOVED from CIS v3.0.0 (was v1.2.0 1.6); opt-in for PCI/older-CIS."
  type        = bool
  default     = false
}

variable "password_require_uppercase" {
  description = "Require >= 1 uppercase letter. REMOVED from CIS v3.0.0 (was v1.2.0 1.5); opt-in for PCI/older-CIS."
  type        = bool
  default     = false
}

variable "password_require_numbers" {
  description = "Require >= 1 number. REMOVED from CIS v3.0.0 (was v1.2.0 1.8); opt-in for PCI/older-CIS."
  type        = bool
  default     = false
}

variable "password_require_symbols" {
  description = "Require >= 1 symbol. REMOVED from CIS v3.0.0 (was v1.2.0 1.7); opt-in for PCI/older-CIS."
  type        = bool
  default     = false
}

variable "password_max_age" {
  description = <<-EOT
    Maximum IAM user password age (days) before rotation is required. 0 = no
    expiration (default; CIS v3.0.0 REMOVED the 90-day expiry recommendation).
    When > 0, passwords expire but hard_expiry stays false so users can still
    reset an expired password themselves.
  EOT
  type        = number
  default     = 0
  validation {
    condition     = var.password_max_age >= 0 && var.password_max_age <= 1095
    error_message = "password_max_age must be between 0 and 1095 days (0 = no expiry)."
  }
}

# ── Account alias (QoL) ──────────────────────────────────────────────────────

variable "create_account_alias" {
  description = <<-EOT
    Set the account's IAM account alias (the vanity console sign-in URL).
    Quality-of-life only -- not a CIS control. Defaults OFF because the alias is
    GLOBALLY UNIQUE across all AWS accounts: a value derived from account_name
    may already be taken and the apply would then fail (EntityAlreadyExists).
    The numeric account-ID sign-in URL keeps working regardless, so an alias
    never locks anyone out.
  EOT
  type        = bool
  default     = false
}

variable "account_alias" {
  description = <<-EOT
    Explicit IAM account alias to set when create_account_alias is true. Must be
    globally unique and 3-63 chars of lowercase letters, digits and hyphens (no
    leading/trailing hyphen, no two hyphens in a row, not a 12-digit number).
    Leave empty to derive one from account_name. Prefer an org-prefixed value
    (e.g. "acme-prod") to avoid global collisions.
  EOT
  type        = string
  default     = ""
}

# ── Default security group lockdown — CIS v3.0.0 5.4 ─────────────────────────

variable "restrict_default_security_group" {
  description = <<-EOT
    CIS v3.0.0 control 5.4: strip ALL ingress and egress rules from the DEFAULT
    security group of the provider region's default VPC (plus any VPCs in
    restrict_default_security_group_vpc_ids). The default SG is ADOPTED, never
    created or deleted. NO-OP when the account has no default VPC or when
    remove_default_vpc is set. Operates on the provider's region only; run per
    region for full coverage.

    DEFAULT OFF (opt-in). This module is dual-published as a standalone registry
    module applied to EXISTING accounts, where resources may still sit on the
    default SG; enabling severs their connectivity (especially egress). Safe to
    enable on freshly bootstrapped accounts. WARNING: enabling is NOT reversible
    by toggling off -- removal only drops the resource from state and does NOT
    restore stripped rules; re-add them manually to undo.
  EOT
  type        = bool
  default     = false
}

variable "restrict_default_security_group_vpc_ids" {
  description = <<-EOT
    Additional VPC IDs, IN THE PROVIDER'S REGION, whose default security group
    should also be locked to zero rules. Opt-in and empty by default: list only
    VPCs you own and do not manage elsewhere -- their default SG is adopted into
    THIS state. The region's default VPC is covered automatically. A stale,
    mistyped, or cross-region id will FAIL the apply. Only takes effect while
    restrict_default_security_group is true.
  EOT
  type        = list(string)
  default     = []
}

# ── IAM Access Analyzer (external access) — CIS v3.0.0 1.20 ──────────────────

variable "enable_account_access_analyzer" {
  description = <<-EOT
    Create an ACCOUNT-scoped IAM Access Analyzer (external access) in this
    account/region. FREE and purely detective (only raises findings -- never
    blocks a launch, denies an API call, or locks anyone out). CIS-ALIGNED
    (v3.0.0 rec. 1.20; Security Hub IAM.28). Regional -- apply per region for
    full coverage. AWS allows only ONE external-access analyzer per account per
    region: if this account already has one the create fails (harmless) -- set
    false or terraform import. Also turn off to avoid duplicate findings when a
    delegated-admin ORGANIZATION analyzer already covers the account.
  EOT
  type        = bool
  default     = true
}

variable "access_analyzer_name" {
  description = <<-EOT
    Name for the ACCOUNT Access Analyzer. Empty (default) derives a stable
    "<account_name>-account-analyzer". Pin this explicitly if account_name may
    change, because the analyzer name (and type) force resource replacement.
  EOT
  type        = string
  default     = ""
}

# ── Default EBS encryption with a customer-managed KMS key (opt-in) ───────────

variable "enable_default_ebs_encryption_cmk" {
  description = <<-EOT
    Point this account/region's DEFAULT EBS encryption at a module-managed
    customer-managed KMS key (CMK) instead of the free AWS-managed aws/ebs key.
    Default OFF: adds ~$1/month/region plus per-request KMS charges, and a CMK
    later disabled/scheduled-for-deletion makes existing CMK-encrypted volumes
    unattachable (boot failures). Requires enable_default_ebs_encryption = true
    (enforced by a precondition). CIS v3.0.0 does NOT require a CMK -- the
    AWS-managed-key default already satisfies 2.2.1; this is defense-in-depth.
  EOT
  type        = bool
  default     = false
}

variable "enable_ebs_cmk_account_ec2_grant" {
  description = <<-EOT
    Allow same-account IAM principals to use the EBS CMK, but ONLY when the call
    is made through EC2/EBS in this region (kms:ViaService + kms:CallerAccount).
    REQUIRED for ordinary least-privilege launch roles (CI/CD, developer,
    Terraform-apply) that have ec2:RunInstances/ec2:CreateVolume but NO explicit
    KMS permissions: without it, setting the CMK as the region default EBS key
    breaks their instance/volume launches. Keep true unless every EBS-launching
    principal is separately granted KMS on this key via its own IAM policy. Only
    applies when enable_default_ebs_encryption_cmk is true.
  EOT
  type        = bool
  default     = true
}

variable "enable_ebs_cmk_autoscaling_grant" {
  description = <<-EOT
    Grant the Auto Scaling service-linked role (AWSServiceRoleForAutoScaling)
    key-use + CreateGrant on the EBS CMK. Keep true: without it, Auto Scaling
    groups (incl. EKS/ECS managed node groups) CANNOT launch instances once the
    CMK is the default, because the SLR's managed policy has no CMK access and
    the role is not editable. Only applies when enable_default_ebs_encryption_cmk
    is true.
  EOT
  type        = bool
  default     = true
}

variable "create_autoscaling_service_linked_role" {
  description = <<-EOT
    Create AWSServiceRoleForAutoScaling so the CMK key policy can safely name it
    (KMS rejects a policy referencing a principal that does not exist yet). Leave
    false when the role already exists (a duplicate create fails); set true on
    fresh accounts that will use Auto Scaling. Only applies when
    enable_default_ebs_encryption_cmk and enable_ebs_cmk_autoscaling_grant are
    both true.
  EOT
  type        = bool
  default     = false
}

variable "ebs_cmk_additional_grant_role_arns" {
  description = <<-EOT
    Extra IAM/service-linked role ARNs that also need to USE the EBS CMK and
    CreateGrant (e.g. EC2 Fleet/Spot SLRs, a custom-suffix Auto Scaling SLR).
    Regular same-account roles are covered by the through-EC2 grant (see
    enable_ebs_cmk_account_ec2_grant); only service-linked roles whose IAM policy
    you cannot edit need explicit key-policy grants. Every ARN listed must
    already exist or the KMS policy apply fails.
  EOT
  type        = list(string)
  default     = []
}

variable "ebs_cmk_deletion_window_in_days" {
  description = "Waiting period (7-30 days) before the EBS CMK is destroyed on terraform destroy, giving a recovery window against accidental deletion/lockout."
  type        = number
  default     = 30
  validation {
    condition     = var.ebs_cmk_deletion_window_in_days >= 7 && var.ebs_cmk_deletion_window_in_days <= 30
    error_message = "ebs_cmk_deletion_window_in_days must be between 7 and 30."
  }
}

variable "ebs_cmk_enable_key_rotation" {
  description = "Enable automatic annual rotation of the EBS CMK key material. Recommended; leave true."
  type        = bool
  default     = true
}

# ── IMDSv2 account default — CIS v3.0.0 5.6 (preventive-config complement) ────

variable "enable_imdsv2_account_default" {
  description = <<-EOT
    Set the account+region EC2 instance-metadata default to require IMDSv2
    (http_tokens = required) for NEW launches that do not specify their own
    metadata options. Does not touch existing instances or launches that set
    their own options, so there is no brick risk to running workloads. Leaves
    the PUT hop limit at "no preference" (omitted-option launches keep the AWS
    default of 1). Region-scoped (like default EBS encryption); apply per region.
    Requires aws provider >= 5.51.0 (see versions.tf). Free.
  EOT
  type        = bool
  default     = true
}

# ── Notifications spine (SNS) ────────────────────────────────────────────────

variable "enable_notifications_topic" {
  description = <<-EOT
    Create the account notifications SNS topic -- the single publish target
    ("spine") that future budget, security, and CloudWatch-alarm features send
    to. Ships with a resource policy allowing in-account CloudWatch and AWS
    Budgets to publish; nothing publishes until a later feature is wired. Safe +
    free (an idle topic with no messages has no cost).
  EOT
  type        = bool
  default     = true
}

variable "notifications_topic_name" {
  description = <<-EOT
    Name for the notifications SNS topic. Empty = derive "<account_name>-notifications".
    Changing it replaces the topic (and drops any subscriptions/confirmations).
  EOT
  type        = string
  default     = ""
}

variable "notification_emails" {
  description = <<-EOT
    Email addresses to subscribe to the notifications topic. Each creates an
    email subscription that AWS sends a confirmation link to; it stays "pending
    confirmation" (Terraform cannot auto-confirm) until a recipient clicks the
    link. Default [] = topic-only seam, no subscriptions.
  EOT
  type        = list(string)
  default     = []
}
