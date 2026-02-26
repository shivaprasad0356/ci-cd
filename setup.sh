#!/bin/bash
set -e # Exit immediately if a command fails

echo "🚀 STEP 1: Installing Terraform..."
wget -q https://releases.hashicorp.com/terraform/1.7.4/terraform_1.7.4_linux_amd64.zip
unzip -o terraform_1.7.4_linux_amd64.zip
chmod +x terraform
sudo mv terraform /usr/local/bin/

echo "🚀 STEP 2: Creating GitHub Connection..."
# This creates it ONLY if it doesn't exist
CONN_ARN=$(aws codestar-connections create-connection --provider-type GitHub --connection-name REVIEW-Link --query 'ConnectionArn' --output text)

echo "⚠️  PAUSE: Please click 'Update Pending Connection' in the AWS Console (Security Requirement)"
echo "Connection ARN: $CONN_ARN"

echo "🚀 STEP 3: Initializing Infrastructure..."
cd infrastructure
terraform init
terraform apply -auto-approve -var="connection_arn=$CONN_ARN"
