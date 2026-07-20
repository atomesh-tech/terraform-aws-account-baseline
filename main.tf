# Runs INSIDE a member account — give it a provider authenticated to that
# account (assume_role into its OrganizationAccountAccessRole). See
# examples/account-bootstrap. All resources are var-gated and additive.

data "aws_partition" "current" {}
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# ── Existing baseline (unchanged) ────────────────────────────────────────────

resource "aws_s3_account_public_access_block" "this" {
  count = var.enable_s3_account_public_access_block ? 1 : 0

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_ebs_encryption_by_default" "this" {
  count   = var.enable_default_ebs_encryption ? 1 : 0
  enabled = true
}

# Deletes the region's default VPC via a script (pure Terraform can't: DeleteVpc
# fails while the default subnets and un-adoptable IGW are attached). Needs the
# AWS CLI; exec_role_arn must be the provider's assume_role (local-exec doesn't
# inherit it). One region per apply.
resource "terraform_data" "delete_default_vpc" {
  count = var.remove_default_vpc ? 1 : 0

  triggers_replace = [var.region, var.exec_role_arn]

  provisioner "local-exec" {
    command     = "${path.module}/scripts/delete-default-vpc.sh"
    interpreter = ["/usr/bin/env", "bash"]
    environment = {
      AWS_REGION    = var.region
      EXEC_ROLE_ARN = var.exec_role_arn
    }
  }
}

# ── IAM account password policy — CIS v3.0.0 1.8 + 1.9 ───────────────────────
# Account-global (IAM isn't regional). Governs only IAM *users* with console
# passwords — NOT the root user, NOT IAM Identity Center (SSO) users. Existing
# passwords are grandfathered (the policy binds only at the next set/change), so
# enabling this cannot lock out current users.
#
# Defaults are CIS v3.0.0-ALIGNED (not "compliant"): min length 14 (1.8) and
# prevent reuse of 24 (1.9). CIS v3.0.0 REMOVED composition (v1.2.0 1.5–1.8) and
# 90-day expiry (v1.2.0 1.11), tracking NIST SP 800-63B; those knobs are exposed
# but default off/none.
#
# SAFETY INVARIANTS (do not change): hard_expiry is never set and is not a
# variable (hard_expiry + expiry is the only admin-only-lockout path);
# allow_users_to_change_password stays true to preserve self-service reset.
#
# WARNING: create = PutAccountPasswordPolicy, which REPLACES any existing account
# policy. On an account whose policy is owned elsewhere, first apply overwrites
# it with these defaults — set the toggle false there.
resource "aws_iam_account_password_policy" "this" {
  # These five checks enforce the password COMPOSITION + 90-day EXPIRY that CIS
  # AWS Foundations v3.0.0 REMOVED (tracking NIST SP 800-63B). This baseline
  # aligns to v3.0.0 (length + reuse only) and leaves composition/expiry as
  # opt-in knobs defaulting off; a shop that still needs them can flip the vars.
  #checkov:skip=CKV_AWS_11:Lowercase requirement removed in CIS v3.0.0; opt-in via password_require_lowercase.
  #checkov:skip=CKV_AWS_15:Uppercase requirement removed in CIS v3.0.0; opt-in via password_require_uppercase.
  #checkov:skip=CKV_AWS_12:Number requirement removed in CIS v3.0.0; opt-in via password_require_numbers.
  #checkov:skip=CKV_AWS_14:Symbol requirement removed in CIS v3.0.0; opt-in via password_require_symbols.
  #checkov:skip=CKV_AWS_9:90-day expiry removed in CIS v3.0.0 (NIST 800-63B); opt-in via password_max_age.
  count = var.enable_iam_account_password_policy ? 1 : 0

  minimum_password_length        = var.password_minimum_length
  allow_users_to_change_password = var.password_allow_users_to_change

  # 0 => omit (AWS rejects 0; valid 1–24). CIS v3.0.0 keeps reuse prevention (1.9).
  password_reuse_prevention = var.password_reuse_prevention > 0 ? var.password_reuse_prevention : null

  # Composition REMOVED in CIS v3.0.0; default false. Opt-in for PCI/older-CIS.
  require_lowercase_characters = var.password_require_lowercase
  require_uppercase_characters = var.password_require_uppercase
  require_numbers              = var.password_require_numbers
  require_symbols              = var.password_require_symbols

  # 0 => omit (AWS rejects 0; valid 1–1095). CIS v3.0.0 removed the expiry rec.
  # When > 0 passwords expire but hard_expiry stays false, so users self-reset.
  max_password_age = var.password_max_age > 0 ? var.password_max_age : null
}

# ── Account alias (QoL; not a CIS control) ───────────────────────────────────
# Vanity console sign-in URL. Default OFF: the alias is GLOBALLY UNIQUE across
# all AWS accounts, so a derived value may already be taken and CreateAccountAlias
# would fail the apply. Never locks anyone out (numeric account-ID URL always works).
locals {
  # lower -> non-[a-z0-9-] runs to '-' -> collapse '-' runs -> strip edge '-'.
  alias_sanitized = trim(
    replace(replace(lower(var.account_name), "/[^a-z0-9-]+/", "-"), "/-+/", "-"),
    "-",
  )
  alias_derived = trim(substr(local.alias_sanitized, 0, 63), "-")
  account_alias = var.account_alias != "" ? var.account_alias : local.alias_derived
}

resource "aws_iam_account_alias" "this" {
  count = var.create_account_alias ? 1 : 0

  account_alias = local.account_alias

  lifecycle {
    precondition {
      # Global uniqueness can't be pre-checked (surfaces at apply); this catches
      # the format errors. The `--` term is load-bearing: RE2 has no lookahead,
      # so an explicit override like "acme--prod" would otherwise pass then die
      # at AWS. (alltrue keeps each check on its own line without a leading `&&`
      # continuation, which some HCL parsers/scanners mis-lex.)
      condition = alltrue([
        can(regex("^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$", local.account_alias)),
        !can(regex("--", local.account_alias)),
        !can(regex("^[0-9]{12}$", local.account_alias)),
      ])
      error_message = <<-EOT
        Computed account alias "${local.account_alias}" is invalid. An IAM account
        alias must be 3-63 characters of lowercase letters, digits and hyphens,
        must not start/end with a hyphen, must not contain two hyphens in a row,
        and must not be a 12-digit number. Set a valid `account_alias` or adjust
        `account_name`.
      EOT
    }
  }
}

# ── Default security group lockdown — CIS v3.0.0 5.4 ─────────────────────────
# aws_default_security_group ADOPTS an existing default SG (never creates/deletes
# one); with no ingress/egress it strips ALL rules => zero in + zero out. Removing
# the resource only drops it from state (does NOT restore rules), so teardown never
# bricks — but toggling off is NOT an undo. Provider region only; run per region.
data "aws_vpcs" "default" {
  # Skipped when off or when the default VPC is being torn down (avoids the
  # adopt-vs-local-exec-delete race with remove_default_vpc). Static filter => the
  # ids are known at plan, so for_each keys are known at plan.
  count = var.restrict_default_security_group && !var.remove_default_vpc ? 1 : 0

  filter {
    name   = "is-default"
    values = ["true"]
  }
}

locals {
  restricted_default_sg_vpc_ids = var.restrict_default_security_group ? toset(concat(
    flatten(data.aws_vpcs.default[*].ids),
    var.restrict_default_security_group_vpc_ids,
  )) : toset([])
}

resource "aws_default_security_group" "restrict" {
  for_each = local.restricted_default_sg_vpc_ids

  vpc_id = each.value

  # No ingress/egress blocks: adoption treats inline rules as absolute and removes
  # every existing rule => the CIS 5.4 state. Do NOT set description (immutable on
  # a default SG) or mix aws_security_group_rule (incompatible).
  tags = merge(var.tags, { Name = "default-restricted-${var.account_name}-${each.key}" })
}

# ── IAM Access Analyzer (external access) — CIS v3.0.0 1.20 ──────────────────
# FREE, regional, purely detective/read-only (raises findings; never blocks a
# call). No `configuration` block: that only exists for the BILLED
# unused_access/internal_access types, so omitting it keeps this $0. One
# external-access analyzer per account per region (create fails harmlessly on a
# collision — set the toggle false or import).
resource "aws_accessanalyzer_analyzer" "account" {
  count = var.enable_account_access_analyzer ? 1 : 0

  analyzer_name = coalesce(var.access_analyzer_name, "${var.account_name}-account-analyzer")
  type          = "ACCOUNT"

  tags = var.tags
}

# ── Default EBS encryption with a customer-managed KMS key (opt-in) ───────────
# Points the region's default EBS key at a module-managed CMK instead of aws/ebs.
# Default OFF: ~$1/mo/region + KMS requests, and a disabled/deleted CMK makes
# existing CMK-encrypted volumes unattachable. CIS v3.0.0 doesn't require a CMK
# (2.2.1 is key-agnostic, already met by the AWS-managed default); this is
# defense-in-depth.
locals {
  ebs_cmk_enabled = var.enable_default_ebs_encryption_cmk
  ebs_cmk_alias   = "alias/${replace(lower(var.account_name), "/[^a-z0-9_-]/", "-")}-ebs-default"

  # Auto Scaling default SLR: its managed policy grants NO CMK access and the SLR
  # is not editable, so it must be named in the key policy explicitly.
  autoscaling_slr_arn = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling"

  ebs_cmk_grant_principals = local.ebs_cmk_enabled ? concat(
    var.enable_ebs_cmk_autoscaling_grant ? [local.autoscaling_slr_arn] : [],
    var.ebs_cmk_additional_grant_role_arns,
  ) : []

  ebs_cmk_account_ec2_grant = local.ebs_cmk_enabled && var.enable_ebs_cmk_account_ec2_grant
  ebs_cmk_ec2_via_service   = "ec2.${data.aws_region.current.name}.${data.aws_partition.current.dns_suffix}"
}

data "aws_iam_policy_document" "ebs_default_cmk" {
  count = local.ebs_cmk_enabled ? 1 : 0

  # (1) Account root full admin — delegates authZ to IAM and can never lock the
  # account out of its own key.
  statement {
    #checkov:skip=CKV_AWS_111:Account-root key-policy admin is the AWS-required statement.
    #checkov:skip=CKV_AWS_356:A KMS key policy's resource is implicitly the key itself.
    #checkov:skip=CKV_AWS_109:Root-account key administration is the documented AWS baseline.
    sid       = "EnableRootAccountAdmin"
    effect    = "Allow"
    actions   = ["kms:*"]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = ["arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }

  # (2) Service-linked roles USE the key (AWS-documented statement 1/2).
  dynamic "statement" {
    for_each = length(local.ebs_cmk_grant_principals) > 0 ? [1] : []
    content {
      sid       = "AllowServiceLinkedRoleKeyUse"
      effect    = "Allow"
      actions   = ["kms:Encrypt", "kms:Decrypt", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:DescribeKey"]
      resources = ["*"]
      principals {
        type        = "AWS"
        identifiers = local.ebs_cmk_grant_principals
      }
    }
  }

  # (3) SLRs CreateGrant for persistent EBS attach (AWS-documented statement 2/2).
  dynamic "statement" {
    for_each = length(local.ebs_cmk_grant_principals) > 0 ? [1] : []
    content {
      sid       = "AllowServiceLinkedRoleCreateGrant"
      effect    = "Allow"
      actions   = ["kms:CreateGrant"]
      resources = ["*"]
      principals {
        type        = "AWS"
        identifiers = local.ebs_cmk_grant_principals
      }
      condition {
        test     = "Bool"
        variable = "kms:GrantIsForAWSResource"
        values   = ["true"]
      }
    }
  }

  # (4) Same-account principals use the key ONLY through EC2/EBS in this region.
  # Without this, ordinary least-privilege launch roles (CI/CD, dev, TF-apply)
  # with ec2:RunInstances but no KMS perms fail to launch once the CMK is default.
  dynamic "statement" {
    for_each = local.ebs_cmk_account_ec2_grant ? [1] : []
    content {
      sid       = "AllowEbsUseThroughEC2ForAccountPrincipals"
      effect    = "Allow"
      actions   = ["kms:Encrypt", "kms:Decrypt", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:DescribeKey"]
      resources = ["*"]
      principals {
        type        = "AWS"
        identifiers = ["arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"]
      }
      condition {
        test     = "StringEquals"
        variable = "kms:ViaService"
        values   = [local.ebs_cmk_ec2_via_service]
      }
      condition {
        test     = "StringEquals"
        variable = "kms:CallerAccount"
        values   = [data.aws_caller_identity.current.account_id]
      }
    }
  }

  # (5) CreateGrant through EC2/EBS for those same-account principals.
  dynamic "statement" {
    for_each = local.ebs_cmk_account_ec2_grant ? [1] : []
    content {
      sid       = "AllowEbsCreateGrantThroughEC2ForAccountPrincipals"
      effect    = "Allow"
      actions   = ["kms:CreateGrant"]
      resources = ["*"]
      principals {
        type        = "AWS"
        identifiers = ["arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"]
      }
      condition {
        test     = "StringEquals"
        variable = "kms:ViaService"
        values   = [local.ebs_cmk_ec2_via_service]
      }
      condition {
        test     = "Bool"
        variable = "kms:GrantIsForAWSResource"
        values   = ["true"]
      }
    }
  }
}

# Optionally guarantee the Auto Scaling SLR exists so the key policy naming it
# doesn't fail (KMS rejects a policy referencing a principal that doesn't exist).
resource "aws_iam_service_linked_role" "autoscaling" {
  count            = local.ebs_cmk_enabled && var.enable_ebs_cmk_autoscaling_grant && var.create_autoscaling_service_linked_role ? 1 : 0
  aws_service_name = "autoscaling.amazonaws.com"
  tags             = var.tags
}

resource "aws_kms_key" "ebs_default" {
  count = local.ebs_cmk_enabled ? 1 : 0

  description             = "Customer-managed default EBS encryption key for ${var.account_name}"
  deletion_window_in_days = var.ebs_cmk_deletion_window_in_days
  enable_key_rotation     = var.ebs_cmk_enable_key_rotation
  policy                  = data.aws_iam_policy_document.ebs_default_cmk[0].json
  tags                    = var.tags

  depends_on = [aws_iam_service_linked_role.autoscaling]
}

resource "aws_kms_alias" "ebs_default" {
  count         = local.ebs_cmk_enabled ? 1 : 0
  name          = local.ebs_cmk_alias
  target_key_id = aws_kms_key.ebs_default[0].key_id
}

resource "aws_ebs_default_kms_key" "this" {
  count      = local.ebs_cmk_enabled ? 1 : 0
  key_arn    = aws_kms_key.ebs_default[0].arn
  depends_on = [aws_ebs_encryption_by_default.this]

  lifecycle {
    precondition {
      condition     = var.enable_default_ebs_encryption
      error_message = "enable_default_ebs_encryption_cmk = true requires enable_default_ebs_encryption = true; otherwise the CMK is set as region default while encryption-by-default is OFF, so new volumes are NOT encrypted and the CMK silently has no effect."
    }
  }
}

# ── IMDSv2 account default — CIS v3.0.0 5.6 (preventive-config complement) ────
# Sets the account+region EC2 metadata default so NEW launches that omit their
# own MetadataOptions require IMDSv2. Existing instances and self-specifying
# launches are untouched (no brick risk). Region-scoped; run per region. On
# destroy, resets to no-preference. Needs aws provider >= 5.51.0 (see versions.tf).
resource "aws_ec2_instance_metadata_defaults" "this" {
  count = var.enable_imdsv2_account_default ? 1 : 0

  http_tokens   = "required"
  http_endpoint = "enabled"
  # http_put_response_hop_limit deliberately left unset: a hard account-wide pin
  # of 1 breaks IMDS credential retrieval from inside containers (ECS/EKS add a
  # hop). Container platforms set their own MetadataOptions per launch template.
}

# ── Notifications spine (SNS) ────────────────────────────────────────────────
# One SNS topic future budget/security/alarm features publish to. Ships a resource
# policy allowing in-account CloudWatch + Budgets to publish (scoped to this
# account). Nothing publishes until a later feature is wired. Idle topic = $0.
locals {
  notifications_topic_name = coalesce(var.notifications_topic_name, "${var.account_name}-notifications")
}

resource "aws_sns_topic" "notifications" {
  #checkov:skip=CKV_AWS_26:SSE intentionally off — encrypting with alias/aws/sns blocks CloudWatch/Budgets from publishing (the AWS-managed key policy grants those services no kms:GenerateDataKey/Decrypt). A CMK with a service-granting key policy is a roadmap item; this is an empty seam topic.
  count = var.enable_notifications_topic ? 1 : 0
  name  = local.notifications_topic_name
  tags  = var.tags
}

data "aws_iam_policy_document" "notifications" {
  count = var.enable_notifications_topic ? 1 : 0

  # Attaching aws_sns_topic_policy REPLACES the implicit default, so reproduce
  # AWS's __default_statement_ID to keep the account's own management/publish
  # access. Uses AWS:SourceAccount (AWS:SourceOwner is deprecated). SNS also
  # unions IAM identity policies, so an sns:* admin is never locked out.
  statement {
    sid    = "DefaultOwnerAccess"
    effect = "Allow"
    actions = [
      "SNS:GetTopicAttributes", "SNS:SetTopicAttributes", "SNS:AddPermission",
      "SNS:RemovePermission", "SNS:DeleteTopic", "SNS:Subscribe",
      "SNS:ListSubscriptionsByTopic", "SNS:Publish", "SNS:Receive",
    ]
    resources = [aws_sns_topic.notifications[0].arn]
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }

  # In-account CloudWatch alarms + AWS Budgets. EventBridge is deliberately NOT a
  # principal here: AWS forbids Condition blocks in SNS policies for EventBridge,
  # so a conditioned grant would DENY its roleless publish path. AWS Budgets is
  # global (us-east-1) and only delivers to a us-east-1 topic — inert elsewhere.
  statement {
    sid       = "AllowServicePublish"
    effect    = "Allow"
    actions   = ["SNS:Publish"]
    resources = [aws_sns_topic.notifications[0].arn]
    principals {
      type        = "Service"
      identifiers = ["cloudwatch.amazonaws.com", "budgets.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_sns_topic_policy" "notifications" {
  count  = var.enable_notifications_topic ? 1 : 0
  arn    = aws_sns_topic.notifications[0].arn
  policy = data.aws_iam_policy_document.notifications[0].json
}

resource "aws_sns_topic_subscription" "notifications_email" {
  for_each = var.enable_notifications_topic ? toset(var.notification_emails) : toset([])

  topic_arn = aws_sns_topic.notifications[0].arn
  protocol  = "email"
  endpoint  = each.value
}
