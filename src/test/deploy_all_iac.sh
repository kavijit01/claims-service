#!/bin/bash
  set -e
  
  # 1. 🔐 AUTHENTICATION CHECK
  echo "🔐 Checking AWS Authentication..."
  if ! aws sts get-caller-identity > /dev/null 2>&1; then
  echo "⚠️ No AWS credentials found. Please configure now:"
  aws configure
  else
  ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text)
echo "✅ Authenticated to Account: $ACCOUNT_ID"
  fi
  
  # 2. 🗑️ PRE-DEPLOYMENT CLEANUP
  # List of stacks in order of dependency (Reverse order for deletion is safest)
  STACKS=("security-stack" "eks-observabality-stack" "eks-nodes-stack" "eks-cluster-stack" "iam-roles-stack" "permissions-stack" "dynamo-db-stack" "s3-bucket-stack" "vpc-stack")
  
  echo "-------------------------------------------------------"
read -p "⚠️ WARNING: This will DELETE existing stacks with these names. Proceed? (y/N): " confirm
if [[ ! "$confirm" =~ ^([yY][eE][sS]|[yY])$ ]]; then
                                                                                          echo "❌ Deployment cancelled."
                                                                                          exit 1
  fi
  
  for STACK in "${STACKS[@]}"; do
  if aws cloudformation describe-stacks --stack-name "$STACK" > /dev/null 2>&1; then
echo "   - Deleting existing stack: $STACK..."
  aws cloudformation delete-stack --stack-name "$STACK"
  aws cloudformation wait stack-delete-complete --stack-name "$STACK"
  echo "   - ✅ $STACK deleted."
  fi
  done
  
  echo "-------------------------------------------------------"
  echo "🚀 Starting Full Infrastructure Deployment..."
  
  # 3. 🏗️ FOUNDATION
  aws cloudformation deploy --template-file ./iac/vpc.yaml --stack-name vpc-stack
  aws cloudformation deploy --template-file ./iac/s3-storage.yaml --stack-name s3-bucket-stack
  aws cloudformation deploy --template-file ./iac/dynamodb-table.yaml --stack-name dynamo-db-stack
  
  # 4. 🔑 IDENTITY
  aws cloudformation deploy --template-file ./iac/app-permissions.yaml --stack-name permissions-stack --capabilities CAPABILITY_NAMED_IAM
  aws cloudformation deploy --template-file ./iac/iam-roles.yaml --stack-name iam-roles-stack --capabilities CAPABILITY_NAMED_IAM
  
  # 5. ☸️ COMPUTE (EKS)
  aws cloudformation deploy --template-file .iac/eks-cluster.yaml --stack-name eks-cluster-stack --parameter-overrides AdminUserArn=$(aws sts get-caller-identity --query Arn --output text) --capabilities CAPABILITY_NAMED_IAM
  aws cloudformation deploy --template-file ./iac/eks-nodes.yaml --stack-name eks-nodes-stack --capabilities CAPABILITY_IAM
  
  # 6. 🛡️ MONITORING & SECURITY
  aws cloudformation deploy --template-file ./iac/eks-observability.yaml --stack-name eks-observabality-stack
  aws cloudformation deploy --template-file ./iac/security-layer.yaml --stack-name security-stack
  
  echo "✅ Infrastructure is LIVE. Use 'aws eks update-kubeconfig' to connect."