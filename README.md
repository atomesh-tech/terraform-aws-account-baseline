# terraform-aws-account-baseline

**Safe, free, account-wide defaults for a member account — plus optional default-VPC teardown. A small Terraform/OpenTofu module.**

[![validate](https://github.com/atomesh-tech/terraform-aws-account-baseline/actions/workflows/validate.yml/badge.svg)](https://github.com/atomesh-tech/terraform-aws-account-baseline/actions/workflows/validate.yml)
[![OpenTofu compatible](https://img.shields.io/badge/OpenTofu-compatible-844FBA?logo=opentofu&logoColor=white)](https://opentofu.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

The "what every new account gets" baseline, **CIS AWS Foundations v3.0.0-aligned**.
Safe, universal defaults on by default — account-wide **S3 Block Public Access**,
**default EBS encryption**, an **IAM password policy** (CIS 1.8 + 1.9), an
**IAM Access Analyzer** (CIS 1.20), an **IMDSv2 account default** (CIS 5.6), and a
**private spoke VPC** (private subnets + route tables + locked default SG, $0 — no
NAT/IGW; requires a per-account `spoke_vpc_primary_cidr`) — plus opt-in hardening:
a **customer-managed EBS KMS key**, **default-SG lockdown** (CIS 5.4), a
**notifications SNS spine**, an account alias, and **default-VPC teardown**. Small
and readable — a seam you grow, not a platform.

> **CIS-ALIGNED, not certified.** Defaults map to specific CIS v3.0.0 controls
> (noted per variable); this module does the *preventive/configuration* half.
> Continuous *detective* assurance (Config rules, conformance packs) is out of
> scope. The removed-in-v3.0.0 password composition/expiry knobs exist but
> default off. See the per-input notes below.

> **This module runs *inside* a member account.** Point its provider at the
> target account by assuming that account's `OrganizationAccountAccessRole` —
> don't run it against your management account.

Extracted from [**landing-zone-starter**](https://github.com/atomesh-tech/landing-zone-starter),
a complete free AWS landing zone. Pairs with
[terraform-aws-organization](https://github.com/atomesh-tech/terraform-aws-organization),
which creates the accounts and hands you the assume-role ARN.

## Usage

```hcl
provider "aws" {
  alias  = "target"
  region = "us-east-1"
  assume_role {
    role_arn = "arn:aws:iam::222233334444:role/OrganizationAccountAccessRole"
  }
}

module "baseline" {
  source  = "atomesh-tech/account-baseline/aws"
  version = "~> 0.1"
  providers = { aws = aws.target }

  account_name = "prod"
}
```

The two encryption/BPA toggles default to `true` and are free and account-global.
A runnable version is in [`examples/basic`](examples/basic).

## ⚠️ Default-VPC teardown: read before enabling

`remove_default_vpc` (default **`false`**) deletes the region's default VPC
(subnets → internet gateway → VPC). Pure Terraform can't do this cleanly — the
attached IGW is un-adoptable and `DeleteVpc` fails while subnets/IGW remain — so
the module shells out to a small script via `local-exec`. When you opt in, this
carries **real runtime requirements** that fail *silently* if unmet:

- **Needs AWS CLI v2 and `bash`** on the machine running Terraform. It will not
  work on a runner without them (e.g. a bare Windows agent).
- **You must pass `exec_role_arn`** whenever your provider assumes into the
  account. `local-exec` does **not** inherit the provider's `assume_role`, so
  without this the script runs against your *ambient* (often management) account
  credentials — the wrong account. Set it to the same role the provider uses:

  ```hcl
  module "baseline" {
    source  = "atomesh-tech/account-baseline/aws"
    version = "~> 0.1"
    providers = { aws = aws.target }

    account_name       = "prod"
    remove_default_vpc = true
    region             = "us-east-1"
    exec_role_arn      = "arn:aws:iam::222233334444:role/OrganizationAccountAccessRole"
  }
  ```

- **One region per apply.** Default VPCs exist in ~17 regions; Terraform can't
  loop a provider over regions, so run per region. (Even AWS Control Tower only
  deletes the home-region default VPC.)
- The assumed role also needs `ec2:DescribeVpcs`, `DeleteVpc`, `DescribeSubnets`,
  `DeleteSubnet`, `DescribeInternetGateways`, `DetachInternetGateway`,
  `DeleteInternetGateway`.

Leave `remove_default_vpc = false` (the default) and the module is inert on this
front — no CLI, no script, no extra permissions needed.

## Requirements

- **Compatible with both Terraform (`>= 1.5`) and OpenTofu.** Uses
  `terraform_data`, so TF `>= 1.4` / OpenTofu `>= 1.4`.
- A provider authenticated to the **target member account**.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| terraform | >= 1.5 |
| aws | >= 5.51.0, < 6.0.0 |

## Providers

| Name | Version |
| ---- | ------- |
| aws | >= 5.51.0, < 6.0.0 |
| terraform | n/a |

## Resources

| Name | Type |
| ---- | ---- |
| [aws_accessanalyzer_analyzer.account](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/accessanalyzer_analyzer) | resource |
| [aws_default_security_group.restrict](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/default_security_group) | resource |
| [aws_default_security_group.spoke](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/default_security_group) | resource |
| [aws_ebs_default_kms_key.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ebs_default_kms_key) | resource |
| [aws_ebs_encryption_by_default.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ebs_encryption_by_default) | resource |
| [aws_ec2_instance_metadata_defaults.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_instance_metadata_defaults) | resource |
| [aws_iam_account_alias.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_account_alias) | resource |
| [aws_iam_account_password_policy.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_account_password_policy) | resource |
| [aws_iam_service_linked_role.autoscaling](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_service_linked_role) | resource |
| [aws_kms_alias.ebs_default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_alias) | resource |
| [aws_kms_key.ebs_default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |
| [aws_route_table.spoke_private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table) | resource |
| [aws_route_table_association.spoke_private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_s3_account_public_access_block.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_account_public_access_block) | resource |
| [aws_sns_topic.notifications](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic) | resource |
| [aws_sns_topic_policy.notifications](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic_policy) | resource |
| [aws_sns_topic_subscription.notifications_email](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic_subscription) | resource |
| [aws_subnet.spoke_private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_vpc.spoke](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc) | resource |
| [aws_vpc_ipv4_cidr_block_association.spoke](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_ipv4_cidr_block_association) | resource |
| [terraform_data.delete_default_vpc](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| access\_analyzer\_name | Name for the ACCOUNT Access Analyzer. Empty (default) derives a stable<br/>"<account\_name>-account-analyzer". Pin this explicitly if account\_name may<br/>change, because the analyzer name (and type) force resource replacement. | `string` | `""` | no |
| account\_alias | Explicit IAM account alias to set when create\_account\_alias is true. Must be<br/>globally unique and 3-63 chars of lowercase letters, digits and hyphens (no<br/>leading/trailing hyphen, no two hyphens in a row, not a 12-digit number).<br/>Leave empty to derive one from account\_name. Prefer an org-prefixed value<br/>(e.g. "acme-prod") to avoid global collisions. | `string` | `""` | no |
| account\_name | Logical name of the account this baseline is applied to (used in tags/descriptions). | `string` | n/a | yes |
| create\_account\_alias | Set the account's IAM account alias (the vanity console sign-in URL).<br/>Quality-of-life only -- not a CIS control. Defaults OFF because the alias is<br/>GLOBALLY UNIQUE across all AWS accounts: a value derived from account\_name<br/>may already be taken and the apply would then fail (EntityAlreadyExists).<br/>The numeric account-ID sign-in URL keeps working regardless, so an alias<br/>never locks anyone out. | `bool` | `false` | no |
| create\_autoscaling\_service\_linked\_role | Create AWSServiceRoleForAutoScaling so the CMK key policy can safely name it<br/>(KMS rejects a policy referencing a principal that does not exist yet). Leave<br/>false when the role already exists (a duplicate create fails); set true on<br/>fresh accounts that will use Auto Scaling. Only applies when<br/>enable\_default\_ebs\_encryption\_cmk and enable\_ebs\_cmk\_autoscaling\_grant are<br/>both true. | `bool` | `false` | no |
| ebs\_cmk\_additional\_grant\_role\_arns | Extra IAM/service-linked role ARNs that also need to USE the EBS CMK and<br/>CreateGrant (e.g. EC2 Fleet/Spot SLRs, a custom-suffix Auto Scaling SLR).<br/>Regular same-account roles are covered by the through-EC2 grant (see<br/>enable\_ebs\_cmk\_account\_ec2\_grant); only service-linked roles whose IAM policy<br/>you cannot edit need explicit key-policy grants. Every ARN listed must<br/>already exist or the KMS policy apply fails. | `list(string)` | `[]` | no |
| ebs\_cmk\_deletion\_window\_in\_days | Waiting period (7-30 days) before the EBS CMK is destroyed on terraform destroy, giving a recovery window against accidental deletion/lockout. | `number` | `30` | no |
| ebs\_cmk\_enable\_key\_rotation | Enable automatic annual rotation of the EBS CMK key material. Recommended; leave true. | `bool` | `true` | no |
| enable\_account\_access\_analyzer | Create an ACCOUNT-scoped IAM Access Analyzer (external access) in this<br/>account/region. FREE and purely detective (only raises findings -- never<br/>blocks a launch, denies an API call, or locks anyone out). CIS-ALIGNED<br/>(v3.0.0 rec. 1.20; Security Hub IAM.28). Regional -- apply per region for<br/>full coverage. AWS allows only ONE external-access analyzer per account per<br/>region: if this account already has one the create fails (harmless) -- set<br/>false or terraform import. Also turn off to avoid duplicate findings when a<br/>delegated-admin ORGANIZATION analyzer already covers the account. | `bool` | `true` | no |
| enable\_default\_ebs\_encryption | Enable EBS encryption by default in this account/region. Safe default; free. | `bool` | `true` | no |
| enable\_default\_ebs\_encryption\_cmk | Point this account/region's DEFAULT EBS encryption at a module-managed<br/>customer-managed KMS key (CMK) instead of the free AWS-managed aws/ebs key.<br/>Default OFF: adds ~$1/month/region plus per-request KMS charges, and a CMK<br/>later disabled/scheduled-for-deletion makes existing CMK-encrypted volumes<br/>unattachable (boot failures). Requires enable\_default\_ebs\_encryption = true<br/>(enforced by a precondition). CIS v3.0.0 does NOT require a CMK -- the<br/>AWS-managed-key default already satisfies 2.2.1; this is defense-in-depth. | `bool` | `false` | no |
| enable\_ebs\_cmk\_account\_ec2\_grant | Allow same-account IAM principals to use the EBS CMK, but ONLY when the call<br/>is made through EC2/EBS in this region (kms:ViaService + kms:CallerAccount).<br/>REQUIRED for ordinary least-privilege launch roles (CI/CD, developer,<br/>Terraform-apply) that have ec2:RunInstances/ec2:CreateVolume but NO explicit<br/>KMS permissions: without it, setting the CMK as the region default EBS key<br/>breaks their instance/volume launches. Keep true unless every EBS-launching<br/>principal is separately granted KMS on this key via its own IAM policy. Only<br/>applies when enable\_default\_ebs\_encryption\_cmk is true. | `bool` | `true` | no |
| enable\_ebs\_cmk\_autoscaling\_grant | Grant the Auto Scaling service-linked role (AWSServiceRoleForAutoScaling)<br/>key-use + CreateGrant on the EBS CMK. Keep true: without it, Auto Scaling<br/>groups (incl. EKS/ECS managed node groups) CANNOT launch instances once the<br/>CMK is the default, because the SLR's managed policy has no CMK access and<br/>the role is not editable. Only applies when enable\_default\_ebs\_encryption\_cmk<br/>is true. | `bool` | `true` | no |
| enable\_iam\_account\_password\_policy | Manage the account's IAM password policy (singleton, account-global).<br/>Defaults are CIS AWS Foundations Benchmark v3.0.0-aligned (min length 14 +<br/>prevent reuse of 24). Affects only IAM users with console passwords -- not<br/>the root user and not IAM Identity Center/SSO users. Existing passwords are<br/>grandfathered, so enabling this does not lock out current users. WARNING:<br/>create = PutAccountPasswordPolicy REPLACES any existing account policy; set<br/>false on SSO-only accounts or where the policy is owned by another tool. | `bool` | `true` | no |
| enable\_imdsv2\_account\_default | Set the account+region EC2 instance-metadata default to require IMDSv2<br/>(http\_tokens = required) for NEW launches that do not specify their own<br/>metadata options. Does not touch existing instances or launches that set<br/>their own options, so there is no brick risk to running workloads. Leaves<br/>the PUT hop limit at "no preference" (omitted-option launches keep the AWS<br/>default of 1). Region-scoped (like default EBS encryption); apply per region.<br/>Requires aws provider >= 5.51.0 (see versions.tf). Free. | `bool` | `true` | no |
| enable\_notifications\_topic | Create the account notifications SNS topic -- the single publish target<br/>("spine") that future budget, security, and CloudWatch-alarm features send<br/>to. Ships with a resource policy allowing in-account CloudWatch and AWS<br/>Budgets to publish; nothing publishes until a later feature is wired. Safe +<br/>free (an idle topic with no messages has no cost). | `bool` | `true` | no |
| enable\_s3\_account\_public\_access\_block | Turn on the account-wide S3 Block Public Access. Safe default for every account. | `bool` | `true` | no |
| enable\_spoke\_vpc | Create a PRIVATE-ONLY spoke VPC (VPC + private subnets + route tables + a<br/>locked zero-rule default SG). NO internet gateway, NO NAT, NO public subnets,<br/>so it costs $0 -- egress is intended to flow through a Transit Gateway hub<br/>(Pro). Enabled BY DEFAULT, but spoke\_vpc\_primary\_cidr is REQUIRED (a<br/>precondition fails the plan with a clear message if this is on and no CIDR is<br/>set), because a shared default CIDR collides once accounts are TGW-attached or<br/>peered. This is a NEW non-default VPC and does not conflict with<br/>remove\_default\_vpc / restrict\_default\_security\_group (which target the DEFAULT<br/>VPC). Set false to skip the VPC entirely. | `bool` | `true` | no |
| exec\_role\_arn | Optional role ARN the teardown script assumes before acting. REQUIRED when<br/>the provider assumes into a member account, because local-exec does not<br/>inherit the provider's credentials -- set it to the same role the provider<br/>uses (e.g. the account's OrganizationAccountAccessRole). Empty = ambient creds. | `string` | `""` | no |
| notification\_emails | Email addresses to subscribe to the notifications topic. Each creates an<br/>email subscription that AWS sends a confirmation link to; it stays "pending<br/>confirmation" (Terraform cannot auto-confirm) until a recipient clicks the<br/>link. Default [] = topic-only seam, no subscriptions. | `list(string)` | `[]` | no |
| notifications\_topic\_name | Name for the notifications SNS topic. Empty = derive "<account\_name>-notifications".<br/>Changing it replaces the topic (and drops any subscriptions/confirmations). | `string` | `""` | no |
| password\_allow\_users\_to\_change | Allow IAM users to change their own password. SAFETY: keep true so users can self-service rotate and are never locked out of a reset. | `bool` | `true` | no |
| password\_max\_age | Maximum IAM user password age (days) before rotation is required. 0 = no<br/>expiration (default; CIS v3.0.0 REMOVED the 90-day expiry recommendation).<br/>When > 0, passwords expire but hard\_expiry stays false so users can still<br/>reset an expired password themselves. | `number` | `0` | no |
| password\_minimum\_length | Minimum IAM user password length. CIS v3.0.0 control 1.8 requires >= 14; a value below 14 forfeits 1.8 alignment. | `number` | `14` | no |
| password\_require\_lowercase | Require >= 1 lowercase letter. REMOVED from CIS v3.0.0 (was v1.2.0 1.6); opt-in for PCI/older-CIS. | `bool` | `false` | no |
| password\_require\_numbers | Require >= 1 number. REMOVED from CIS v3.0.0 (was v1.2.0 1.8); opt-in for PCI/older-CIS. | `bool` | `false` | no |
| password\_require\_symbols | Require >= 1 symbol. REMOVED from CIS v3.0.0 (was v1.2.0 1.7); opt-in for PCI/older-CIS. | `bool` | `false` | no |
| password\_require\_uppercase | Require >= 1 uppercase letter. REMOVED from CIS v3.0.0 (was v1.2.0 1.5); opt-in for PCI/older-CIS. | `bool` | `false` | no |
| password\_reuse\_prevention | Number of previous passwords IAM users may not reuse. CIS v3.0.0 control 1.9; 24 is the AWS maximum. 0 omits the setting. | `number` | `24` | no |
| region | Region whose default VPC to delete (used by the teardown script). Should match the provider's region. | `string` | `"us-east-1"` | no |
| remove\_default\_vpc | Delete the region's default VPC (subnets -> internet gateway -> VPC) via a<br/>local-exec teardown script. Requires the AWS CLI on the machine running<br/>Terraform. Covers only `region`; run per region for full coverage. | `bool` | `false` | no |
| restrict\_default\_security\_group | CIS v3.0.0 control 5.4: strip ALL ingress and egress rules from the DEFAULT<br/>security group of the provider region's default VPC (plus any VPCs in<br/>restrict\_default\_security\_group\_vpc\_ids). The default SG is ADOPTED, never<br/>created or deleted. NO-OP when the account has no default VPC or when<br/>remove\_default\_vpc is set. Operates on the provider's region only; run per<br/>region for full coverage.<br/><br/>DEFAULT OFF (opt-in). This module is dual-published as a standalone registry<br/>module applied to EXISTING accounts, where resources may still sit on the<br/>default SG; enabling severs their connectivity (especially egress). Safe to<br/>enable on freshly bootstrapped accounts. WARNING: enabling is NOT reversible<br/>by toggling off -- removal only drops the resource from state and does NOT<br/>restore stripped rules; re-add them manually to undo. | `bool` | `false` | no |
| restrict\_default\_security\_group\_vpc\_ids | Additional VPC IDs, IN THE PROVIDER'S REGION, whose default security group<br/>should also be locked to zero rules. Opt-in and empty by default: list only<br/>VPCs you own and do not manage elsewhere -- their default SG is adopted into<br/>THIS state. The region's default VPC is covered automatically. A stale,<br/>mistyped, or cross-region id will FAIL the apply. Only takes effect while<br/>restrict\_default\_security\_group is true. | `list(string)` | `[]` | no |
| spoke\_vpc\_az\_count | Number of Availability Zones to spread private subnets across (one subnet per<br/>AZ per source CIDR). The module reads the region's available AZs and takes the<br/>first N deterministically, clamping to however many the region actually offers<br/>(regions with fewer AZs never error). Default 2. | `number` | `2` | no |
| spoke\_vpc\_name | Name tag for the spoke VPC and the base for its subnet/route-table/SG Name<br/>tags. Empty (default) derives "<account\_name>-spoke". Purely cosmetic (tags);<br/>changing it does not force replacement of the VPC. | `string` | `""` | no |
| spoke\_vpc\_primary\_cidr | Primary IPv4 CIDR for the spoke VPC (e.g. "10.0.0.0/16"). REQUIRED when<br/>enable\_spoke\_vpc is true -- deliberately no default, because account-baseline<br/>runs PER ACCOUNT and a shared CIDR collides the moment accounts are<br/>TGW-attached or peered. Private subnets are carved from this range (and from<br/>spoke\_vpc\_secondary\_cidrs) via cidrsubnet. | `string` | `""` | no |
| spoke\_vpc\_secondary\_cidrs | Additional IPv4 CIDRs to associate with the spoke VPC (via<br/>aws\_vpc\_ipv4\_cidr\_block\_association). Private subnets are carved from these<br/>too, one per AZ, using the same spoke\_vpc\_subnet\_newbits. Each must be a valid<br/>IPv4 CIDR and must not overlap the primary or each other (AWS rejects<br/>overlapping associations at apply). Default [] = primary range only. | `list(string)` | `[]` | no |
| spoke\_vpc\_subnet\_newbits | Additional prefix bits added to each source CIDR when carving subnets<br/>(cidrsubnet newbits). E.g. 8 turns a /16 into /24 subnets. Must leave room for<br/>spoke\_vpc\_az\_count subnets per source CIDR: 2^spoke\_vpc\_subnet\_newbits >=<br/>spoke\_vpc\_az\_count (enforced by a precondition on aws\_vpc.spoke, not here,<br/>because cross-variable references in a variable validation require<br/>Terraform/OpenTofu >= 1.9 and this module supports >= 1.5). Default 8. | `number` | `8` | no |
| tags | Tags to apply to taggable baseline resources. The current baseline resources<br/>(account-wide S3 Block Public Access, default EBS encryption) are<br/>account-global toggles that are not taggable, so tags are held for future<br/>taggable additions and echoed via the `tags` output for callers to reuse. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| account\_access\_analyzer\_arn | ARN of the ACCOUNT (external-access) Access Analyzer for this account/region, or null when disabled. |
| account\_access\_analyzer\_enabled | Whether the ACCOUNT (external-access) Access Analyzer was actually created in this account/region. |
| account\_alias | The IAM account alias set for this account, or null when not managed. |
| account\_name | Logical name of the account this baseline was applied to. |
| default\_ebs\_encryption\_cmk\_alias | Alias of the customer-managed EBS default KMS key, or null when disabled. |
| default\_ebs\_encryption\_cmk\_arn | ARN of the customer-managed EBS default KMS key, or null when disabled. |
| default\_ebs\_encryption\_cmk\_enabled | Whether default EBS encryption uses a customer-managed KMS key (CMK) in this account/region. |
| default\_ebs\_encryption\_enabled | Whether default EBS encryption was enabled for this account/region. |
| default\_security\_group\_restricted | Whether default-SG lockdown (CIS v3.0.0 5.4) is enabled for this apply. |
| iam\_account\_password\_policy\_enabled | Whether the account IAM password policy was managed by this baseline. |
| imdsv2\_account\_default\_enabled | Whether the account+region IMDS default was set to require IMDSv2 for new launches (CIS-ALIGNED v3.0.0 5.6, preventive-config complement). |
| notifications\_topic\_arn | ARN of the account notifications SNS topic (the publish seam), or null when disabled. Wire future budget/alarm/security features to this. |
| notifications\_topic\_name | Name of the account notifications SNS topic, or null when disabled. |
| restricted\_default\_security\_group\_vpc\_ids | VPC IDs whose default security group this baseline locked to zero rules (provider-region default VPC plus any explicitly opted-in). |
| s3\_public\_access\_block\_enabled | Whether the account-wide S3 Block Public Access was applied. |
| spoke\_default\_security\_group\_id | ID of the spoke VPC's locked (zero-rule) default security group, or null when disabled. |
| spoke\_private\_route\_table\_ids | Map of subnet key to private route-table ID; the Pro TGW layer adds egress routes to these. |
| spoke\_private\_subnet\_ids | Map of subnet key ("<source-cidr>-<az>") to private subnet ID. Consumed by the Pro TGW layer to attach the VPC. |
| spoke\_vpc\_enabled | Whether the private spoke VPC was created in this account/region. |
| spoke\_vpc\_id | ID of the private spoke VPC, or null when disabled. |
| spoke\_vpc\_primary\_cidr | Primary IPv4 CIDR of the spoke VPC, or null when disabled. |
| spoke\_vpc\_secondary\_cidrs | Secondary IPv4 CIDRs associated with the spoke VPC (sorted). |
| tags | The tags passed to this baseline, for callers to reuse on account-level resources they add. |
<!-- END_TF_DOCS -->

## License

MIT © Atomesh. See [LICENSE](LICENSE).
