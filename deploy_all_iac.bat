@echo off
setlocal enabledelayedexpansion

:: 1. 🔐 AUTHENTICATION CHECK
echo 🔐 Checking AWS Authentication...
aws sts get-caller-identity >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo ⚠️ No AWS credentials found. Please configure now:
    aws configure
) else (
    for /f "tokens=*" %%i in ('aws sts get-caller-identity --query "Account" --output text') do (
        set ACCOUNT_ID=%%i
        set ADMIN_ARN=%%j
    )
    :: We fetch the full ARN of the current user to pass to EKS Access Entry
    for /f "tokens=*" %%a in ('aws sts get-caller-identity --query "Arn" --output text') do set USER_ARN=%%a
    echo ✅ Authenticated as: !USER_ARN!
)

:: 2. 🗑️ PRE-DEPLOYMENT CLEANUP
echo -------------------------------------------------------
set /p confirm="⚠️ WARNING: This will DELETE existing stacks. Proceed? (y/N): "
if /i "!confirm!" NEQ "y" (
    echo ❌ Deployment cancelled.
    exit /b 1
)

:: REARRANGED DELETE ORDER: iam-roles-stack MUST be deleted before eks-cluster-stack
:: because it contains the Pod Identity Association link.
set STACKS=ecr-stack security-stack eks-observabality-stack claims-pod-link-stack eks-nodes-stack iam-roles-stack eks-cluster-stack permissions-stack dynamo-db-stack s3-bucket-stack vpc-stack

for %%S in (%STACKS%) do (
    aws cloudformation describe-stacks --stack-name %%S >nul 2>&1
    if !ERRORLEVEL! EQU 0 (
        echo    - Deleting existing stack: %%S...
        aws cloudformation delete-stack --stack-name %%S
        aws cloudformation wait stack-delete-complete --stack-name %%S
        echo    - ✅ %%S deleted.
    )
)

echo -------------------------------------------------------
echo 🚀 Starting Full Infrastructure Deployment...

:: 3. 🏗️ FOUNDATION (Storage & Network)
aws cloudformation deploy --template-file ./iac/vpc.yaml --stack-name vpc-stack
aws cloudformation deploy --template-file ./iac/s3-storage.yaml --stack-name s3-bucket-stack
aws cloudformation deploy --template-file ./iac/dynamodb-table.yaml --stack-name dynamo-db-stack

:: 4. 🔐 PERMISSIONS (IAM Policies)
:: We deploy this early because the roles stack needs to import the Policy ARN
aws cloudformation deploy --template-file ./iac/app-permissions.yaml --stack-name permissions-stack --capabilities CAPABILITY_NAMED_IAM

:: 5. 🔑 THE IDENTITY (IAM Roles)
:: MOVED HERE: This stack now links the roles to the Cluster created in Step 5
echo 🔑 Creating IAM Roles and Pod Identity Link...
aws cloudformation deploy --template-file ./iac/iam-roles.yaml --stack-name iam-roles-stack --capabilities CAPABILITY_NAMED_IAM

:: 6. ☸️ THE BRAIN (EKS Cluster)
:: Deployment includes the Pod Identity Agent Add-on and Admin Access Entry
echo ☸️ Creating EKS Cluster (this takes ~15 mins)...
aws cloudformation deploy --template-file ./iac/eks-cluster.yaml --stack-name eks-cluster-stack --capabilities CAPABILITY_NAMED_IAM

:: 7. 🏗️ THE MUSCLE (EKS Nodes)
aws cloudformation deploy --template-file ./iac/eks-nodes.yaml --stack-name eks-nodes-stack --capabilities CAPABILITY_IAM

:: 8. 🔌 CONNECTIVITY & K8S IDENTITY
echo 🔌 Updating local kubeconfig...
aws eks update-kubeconfig --region us-east-2 --name Claims-Service-Cluster

echo 🆔 Applying Kubernetes Service Account...
kubectl apply -f ./iac/claims-service-account.yaml

:: 9. Link the ServiceAccount to the IAM Role
echo 🔗 Creating Pod Identity Association...
aws cloudformation deploy --template-file ./iac/pod-identity-link.yaml --stack-name claims-pod-link-stack

:: 10. 🛠️ HELM PREREQUISITES
echo 🛠️ Installing cert-manager...
helm repo add jetstack https://charts.jetstack.io --force-update
helm repo update
helm upgrade --install cert-manager jetstack/cert-manager --namespace cert-manager --create-namespace --version v1.17.1 --set installCRDs=true --wait
timeout /t 10 /nobreak >nul

:: 11. 🛡️ MONITORING & SECURITY
aws cloudformation deploy --template-file ./iac/eks-observability.yaml --stack-name eks-observabality-stack
aws cloudformation deploy --template-file ./iac/security-layer.yaml --stack-name security-stack

:: 12. 🛡️ ECR REPO
echo 📦 Creating ECR Repository...
aws cloudformation deploy --template-file ./iac/ecr-repo.yaml --stack-name ecr-stack

echo -------------------------------------------------------
echo ✅ Infrastructure is LIVE.
echo 🚀 Next step: Deploy your application code!
pause