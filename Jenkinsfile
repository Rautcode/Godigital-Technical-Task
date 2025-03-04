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
        powershell '''
        $env:AWS_ACCESS_KEY_ID = "${AWS_ACCESS_KEY_ID}"
        $env:AWS_SECRET_ACCESS_KEY = "${AWS_SECRET_ACCESS_KEY}"
        terraform plan -out=tfplan
        '''
    }
}
        
        stage('Terraform Apply') {
            steps {
                powershell 'terraform apply -auto-approve tfplan'
                
                // Store Terraform outputs as environment variables
                script {
                    env.ECR_REPOSITORY_URL = powershell(returnStdout: true, script: 'terraform output -raw ecr_repository_url').trim()
                    env.LAMBDA_FUNCTION_NAME = powershell(returnStdout: true, script: 'terraform output -raw lambda_function_name').trim()
                }
            }
        }
        
        stage('Build and Push Docker Image') {
            steps {
                bat '''
                REM Login to AWS ECR
                for /f "tokens=*" %%i in ('aws ecr get-login-password --region %AWS_REGION%') do set ECR_LOGIN_PASSWORD=%%i
                echo %ECR_LOGIN_PASSWORD% | docker login --username AWS --password-stdin %ECR_REPOSITORY_URL%

                REM Build Docker image using Docker v2 format (not OCI)
                docker build --format=docker -t %ECR_REPOSITORY_URL%:%DOCKER_IMAGE_TAG% .

                REM Push Docker image (Ensure v2 format)
                docker push %ECR_REPOSITORY_URL%:%DOCKER_IMAGE_TAG%
                '''
            }
        }
        
        stage('Update Lambda Function') {
            steps {
                powershell '''
                aws lambda update-function-code `
                    --region ${env.AWS_REGION} `
                    --function-name ${env.LAMBDA_FUNCTION_NAME} `
                    --image-uri ${env.ECR_REPOSITORY_URL}:${env.DOCKER_IMAGE_TAG}
                '''
            }
        }
        
        stage('Test Lambda Function') {
            steps {
                powershell '''
                # Create test event JSON
                $testEvent = @"
                {
                    "s3_bucket": "$(terraform output -raw s3_bucket_name)",
                    "s3_key": "test-data.csv"
                }
                "@
                $testEvent | Out-File -FilePath test-event.json -Encoding utf8
                
                # Invoke Lambda function
                aws lambda invoke `
                    --region ${env.AWS_REGION} `
                    --function-name ${env.LAMBDA_FUNCTION_NAME} `
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
