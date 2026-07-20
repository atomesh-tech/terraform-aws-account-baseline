terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source = "hashicorp/aws"
      # >= 5.51.0 for aws_ec2_instance_metadata_defaults (IMDSv2 account default).
      version = ">= 5.51.0, < 6.0.0"
    }
  }
}
