pipeline {
    agent any
    
    environment {
        AWS_REGION = 'us-east-1'
        ECR_REPO_NAME = 'data-pipeline-repo'
        DOCKER_IMAGE_TAG = 'latest'
        TF_VAR_rds_password = credentials('rds-password')

        // AWS credentials for authentication
        AWS_ACCESS_KEY_ID = credentials('aws-access-key')
        AWS_SECRET_ACCESS_KEY = credentials('aws-secret-key')
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }
        
        stage('Terraform Init') {
            steps {
                powershell '''
                $env:AWS_ACCESS_KEY_ID = "${env:AWS_ACCESS_KEY_ID}"
                $env:AWS_SECRET_ACCESS_KEY = "${env:AWS_SECRET_ACCESS_KEY}"

                terraform init
                '''
            }
        }
        
        stage('Terraform Plan') {
            steps {
                powershell '''
                $env:AWS_ACCESS_KEY_ID = "${env:AWS_ACCESS_KEY_ID}"
                $env:AWS_SECRET_ACCESS_KEY = "${env:AWS_SECRET_ACCESS_KEY}"

                terraform plan -out=tfplan
                '''
            }
        }
        
        stage('Terraform Apply') {
            steps {
                powershell '''
                $env:AWS_ACCESS_KEY_ID = "${env:AWS_ACCESS_KEY_ID}"
                $env:AWS_SECRET_ACCESS_KEY = "${env:AWS_SECRET_ACCESS_KEY}"

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
                # Set AWS credentials
                $env:AWS_ACCESS_KEY_ID = "${env:AWS_ACCESS_KEY_ID}"
                $env:AWS_SECRET_ACCESS_KEY = "${env:AWS_SECRET_ACCESS_KEY}"

                # Login to AWS ECR
                aws ecr get-login-password --region ${env:AWS_REGION} | docker login --username AWS --password-stdin $env:ECR_REPOSITORY_URL

                # Build Docker image (Force Docker v2, Avoid OCI Format)
                docker build --platform linux/amd64 --tag "$env:ECR_REPOSITORY_URL`:latest" .

                # Verify image format before pushing
                $imageFormat = docker inspect "$env:ECR_REPOSITORY_URL`:latest" | ConvertFrom-Json | Select-Object -ExpandProperty Config | Select-Object -ExpandProperty MediaType
                if ($imageFormat -eq "application/vnd.oci.image.manifest.v1+json") {
                    Write-Host "❌ ERROR: Docker image is in OCI format! Aborting."
                    exit 1
                }

                # Push Docker image to ECR
                docker push "$env:ECR_REPOSITORY_URL`:latest"
                '''
            }
        }
        
        stage('Update Lambda Function') {
            steps {
                powershell '''
                # Set AWS credentials
                $env:AWS_ACCESS_KEY_ID = "${env:AWS_ACCESS_KEY_ID}"
                $env:AWS_SECRET_ACCESS_KEY = "${env:AWS_SECRET_ACCESS_KEY}"

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
