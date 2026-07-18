# Runs INSIDE a member account — give it a provider authenticated to that
# account (assume_role into its OrganizationAccountAccessRole). See
# examples/account-bootstrap.

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
