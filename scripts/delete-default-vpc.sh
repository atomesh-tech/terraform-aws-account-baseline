#!/usr/bin/env bash
##############################################################################
# Delete the default VPC in a single region, end to end.
#
# Pure Terraform can't do this cleanly: aws_default_vpc's delete only calls
# DeleteVpc, which fails with DependencyViolation while the default subnets and
# the attached internet gateway still exist — and the IGW can't be adopted by
# any aws_default_* resource. So account-baseline shells out to this script,
# which does the imperative teardown AWS itself requires (subnets → IGW → VPC).
#
# Invoked by the module's terraform_data.delete_default_vpc via local-exec.
# Requires: awscli v2, jq NOT required (uses --query).
#
# Env:
#   AWS_REGION       region to operate in (required)
#   EXEC_ROLE_ARN    optional: role to assume first. IMPORTANT — Terraform
#                    provisioners do NOT inherit the provider's assume_role, so
#                    when the provider assumes into a member account this must be
#                    set to that same role, or the script hits the wrong account.
##############################################################################
set -euo pipefail

region="${AWS_REGION:?AWS_REGION is required}"

# If a role is given, assume it so we operate in the intended account.
if [[ -n "${EXEC_ROLE_ARN:-}" ]]; then
  creds="$(aws sts assume-role \
    --role-arn "$EXEC_ROLE_ARN" \
    --role-session-name lz-default-vpc-teardown \
    --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]' \
    --output text)"
  AWS_ACCESS_KEY_ID="$(echo "$creds" | cut -f1)"
  AWS_SECRET_ACCESS_KEY="$(echo "$creds" | cut -f2)"
  AWS_SESSION_TOKEN="$(echo "$creds" | cut -f3)"
  export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
fi

vpc="$(aws ec2 describe-vpcs --region "$region" \
  --filters Name=isDefault,Values=true \
  --query 'Vpcs[0].VpcId' --output text)"

if [[ "$vpc" == "None" || -z "$vpc" ]]; then
  echo "[default-vpc] none in $region — nothing to do"
  exit 0
fi
echo "[default-vpc] deleting $vpc in $region"

# 1. Subnets
for sn in $(aws ec2 describe-subnets --region "$region" \
    --filters Name=vpc-id,Values="$vpc" \
    --query 'Subnets[].SubnetId' --output text); do
  echo "  - subnet $sn"
  aws ec2 delete-subnet --region "$region" --subnet-id "$sn"
done

# 2. Internet gateway (detach then delete)
igw="$(aws ec2 describe-internet-gateways --region "$region" \
  --filters Name=attachment.vpc-id,Values="$vpc" \
  --query 'InternetGateways[0].InternetGatewayId' --output text)"
if [[ "$igw" != "None" && -n "$igw" ]]; then
  echo "  - igw $igw"
  aws ec2 detach-internet-gateway --region "$region" --internet-gateway-id "$igw" --vpc-id "$vpc"
  aws ec2 delete-internet-gateway --region "$region" --internet-gateway-id "$igw"
fi

# 3. The VPC (default SG, NACL, route table go with it)
aws ec2 delete-vpc --region "$region" --vpc-id "$vpc"
echo "[default-vpc] done ($vpc removed from $region)"
