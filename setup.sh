#!/bin/bash
set -e

echo "--------------------------------------------------"
echo "🚀 AUTOMATION: STARTING INFRASTRUCTURE SETUP"
echo "--------------------------------------------------"

# 1. Install Terraform
echo "📦 Installing Terraform..."
wget -q https://releases.hashicorp.com/terraform/1.7.4/terraform_1.7.4_linux_amd64.zip
unzip -o terraform_1.7.4_linux_amd64.zip
chmod +x terraform
sudo mv terraform /usr/local/bin/

# 2. Create Connection
echo "🔗 Creating GitHub Connection..."
# We use '|| true' so the script doesn't crash if the connection already exists
aws codestar-connections create-connection --provider-type GitHub --connection-name REVIEW-Link || true
CONN_ARN=$(aws codestar-connections list-connections --query 'Connections[?ConnectionName==`REVIEW-Link`].ConnectionArn' --output text)

echo "--------------------------------------------------"
echo "⚠️  ACTION REQUIRED: PLEASE AUTHORIZE THE CONNECTION"
echo "1. Go to AWS Console -> Developer Tools -> Settings -> Connections"
echo "2. Click 'REVIEW-Link' and 'Update Pending Connection'."
echo "3. Once it is 'Available', press [ENTER] here to continue..."
echo "--------------------------------------------------"
read -p ""

# 3. Run Terraform
echo "🏗️  Deploying Infrastructure..."
cd infrastructure
terraform init
terraform apply -auto-approve -var="connection_arn=$CONN_ARN"

echo "--------------------------------------------------"
echo "✅ SUCCESS: PIPELINE IS LIVE!"
echo "Now, go to GitHub and create a Release (Tag) to trigger the deploy."
echo "--------------------------------------------------"
