:: Build the jar
mvn clean package -DskipTests

:: Fetch URI and Push to ECR
FOR /F "tokens=*" %%i IN ('aws cloudformation describe-stacks --stack-name ecr-stack --query "Stacks[0].Outputs[?OutputKey=='RepositoryUri'].OutputValue" --output text') DO SET ECR_URI=%%i

docker build -t claims-service .
docker tag claims-service:latest %ECR_URI%:latest

aws ecr get-login-password --region us-east-2 | docker login --username AWS --password-stdin %ECR_URI%
docker push %ECR_URI%:latest

kubectl apply -f ./k8s/deployment.yaml
kubectl rollout restart deployment claims-service
kubectl logs -f deployment/claims-service

kubectl get svc claims-service-lb