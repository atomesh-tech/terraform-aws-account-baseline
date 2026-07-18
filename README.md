# terraform-aws-account-baseline

**Safe, free, account-wide defaults for a member account — plus optional default-VPC teardown. A small Terraform/OpenTofu module.**

[![validate](https://github.com/atomesh-tech/terraform-aws-account-baseline/actions/workflows/validate.yml/badge.svg)](https://github.com/atomesh-tech/terraform-aws-account-baseline/actions/workflows/validate.yml)
[![OpenTofu compatible](https://img.shields.io/badge/OpenTofu-compatible-844FBA?logo=opentofu&logoColor=white)](https://opentofu.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

The "what every new account gets" baseline: account-wide **S3 Block Public
Access**, **default EBS encryption**, and an opt-in **default-VPC teardown**.
Small on purpose — a seam you grow, not a platform.

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
| aws | ~> 5.0 |

## Providers

| Name | Version |
| ---- | ------- |
| aws | ~> 5.0 |
| terraform | n/a |

## Resources

| Name | Type |
| ---- | ---- |
| [aws_ebs_encryption_by_default.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ebs_encryption_by_default) | resource |
| [aws_s3_account_public_access_block.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_account_public_access_block) | resource |
| [terraform_data.delete_default_vpc](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| account\_name | Logical name of the account this baseline is applied to (used in tags/descriptions). | `string` | n/a | yes |
| enable\_default\_ebs\_encryption | Enable EBS encryption by default in this account/region. Safe default; free. | `bool` | `true` | no |
| enable\_s3\_account\_public\_access\_block | Turn on the account-wide S3 Block Public Access. Safe default for every account. | `bool` | `true` | no |
| exec\_role\_arn | Optional role ARN the teardown script assumes before acting. REQUIRED when<br/>the provider assumes into a member account, because local-exec does not<br/>inherit the provider's credentials -- set it to the same role the provider<br/>uses (e.g. the account's OrganizationAccountAccessRole). Empty = ambient creds. | `string` | `""` | no |
| region | Region whose default VPC to delete (used by the teardown script). Should match the provider's region. | `string` | `"us-east-1"` | no |
| remove\_default\_vpc | Delete the region's default VPC (subnets -> internet gateway -> VPC) via a<br/>local-exec teardown script. Requires the AWS CLI on the machine running<br/>Terraform. Covers only `region`; run per region for full coverage. | `bool` | `false` | no |
| tags | Tags to apply to taggable baseline resources. The current baseline resources<br/>(account-wide S3 Block Public Access, default EBS encryption) are<br/>account-global toggles that are not taggable, so tags are held for future<br/>taggable additions and echoed via the `tags` output for callers to reuse. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| account\_name | Logical name of the account this baseline was applied to. |
| default\_ebs\_encryption\_enabled | Whether default EBS encryption was enabled for this account/region. |
| s3\_public\_access\_block\_enabled | Whether the account-wide S3 Block Public Access was applied. |
| tags | The tags passed to this baseline, for callers to reuse on account-level resources they add. |
<!-- END_TF_DOCS -->

## License

MIT © Atomesh. See [LICENSE](LICENSE).
