terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# This module runs INSIDE a member account. In a real setup, point the provider
# at that account by assuming its OrganizationAccountAccessRole:
#
#   provider "aws" {
#     region = "us-east-1"
#     assume_role {
#       role_arn = "arn:aws:iam::222233334444:role/OrganizationAccountAccessRole"
#     }
#   }
#
# The example uses a plain provider so it validates without real credentials.
provider "aws" {
  region = "us-east-1"
}

module "baseline" {
  source = "../../"

  account_name = "workload"

  # Safe, free, account-wide defaults (both default to true):
  enable_s3_account_public_access_block = true
  enable_default_ebs_encryption         = true

  # Default-VPC teardown is OFF by default. If you enable it, read the README:
  # it shells out to an AWS CLI v2 + bash script, only covers `region`, and when
  # your provider assumes into the account you MUST pass exec_role_arn (the same
  # role) because local-exec does not inherit provider credentials.
  #
  # remove_default_vpc = true
  # region             = "us-east-1"
  # exec_role_arn      = "arn:aws:iam::222233334444:role/OrganizationAccountAccessRole"

  tags = {
    ManagedBy = "terraform-aws-account-baseline"
  }
}

output "account_name" {
  value = module.baseline.account_name
}
