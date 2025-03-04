pipeline {
    agent any
    
    environment {
        AWS_REGION = 'us-east-1'
        ECR_REPO_NAME = 'data-pipeline-repo'
        DOCKER_IMAGE_TAG = 'latest'
        TF_VAR_rds_password = credentials('rds-password')
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }
        
        stage('Terraform Init') {
            steps {
                powershell 'terraform init'
            }
        }
        
        stage('Terraform Plan') {
            steps {
                powershell 'terraform plan -out=tfplan'
            }
        }
        
        stage('Terraform Apply') {
            steps {
                powershell '''
                terraform apply -auto-approve tfplan
                
                # Store Terraform outputs as environment variables
                $env:ECR_REPOSITORY_URL = terraform output -raw ecr_repository_url
                $env:LAMBDA_FUNCTION_NAME = terraform output -raw lambda_function_name
                '''
            }
        }
        
        stage('Build and Push Docker Image') {
            steps {
                powershell '''
                # Login to AWS ECR
                aws ecr get-login-password --region ${env:AWS_REGION} | docker login --username AWS --password-stdin $env:ECR_REPOSITORY_URL

                # Build Docker image (Force Docker v2, Avoid OCI Format)
                docker build --platform linux/amd64 -t "$env:ECR_REPOSITORY_URL`:latest" .

                # Verify image format before pushing
                docker inspect "$env:ECR_REPOSITORY_URL`:latest" | ConvertFrom-Json | Select-Object -ExpandProperty Config | Select-Object -ExpandProperty MediaType

                # Push Docker image to ECR
                docker push "$env:ECR_REPOSITORY_URL`:latest"
                '''
            }
        }
        
        stage('Update Lambda Function') {
            steps {
                powershell '''
                # Update Lambda function with new container image
                aws lambda update-function-code `
                    --region ${env:AWS_REGION} `
                    --function-name $env:LAMBDA_FUNCTION_NAME `
                    --image-uri "$env:ECR_REPOSITORY_URL`:latest"
                '''
            }
        }
        
        stage('Test Lambda Function') {
            steps {
                powershell '''
                # Create test event file
                @"
                {
                    "s3_bucket": "$(terraform output -raw s3_bucket_name)",
                    "s3_key": "test-data.csv"
                }
                "@ | Out-File -FilePath test-event.json -Encoding utf8
                
                # Invoke Lambda function with test event
                aws lambda invoke `
                    --region ${env:AWS_REGION} `
                    --function-name $env:LAMBDA_FUNCTION_NAME `
                    --payload file://test-event.json `
                    --cli-binary-format raw-in-base64-out `
                    lambda-response.json
                
                # Print the Lambda response
                Get-Content lambda-response.json
                '''
            }
        }
    }
    
    post {
        always {
            // Clean up
            powershell 'Remove-Item -Force test-event.json, lambda-response.json -ErrorAction Ignore'
        }
        success {
            echo 'Pipeline completed successfully!'
        }
        failure {
            echo 'Pipeline failed!'
        }
    }
}

