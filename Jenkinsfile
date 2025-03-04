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
                sh 'terraform init'
            }
        }
        
        stage('Terraform Plan') {
            steps {
                sh 'terraform plan -out=tfplan'
            }
        }
        
        stage('Terraform Apply') {
            steps {
                sh 'terraform apply -auto-approve tfplan'
                
                // Store terraform outputs as environment variables
                script {
                    env.ECR_REPOSITORY_URL = sh(script: 'terraform output -raw ecr_repository_url', returnStdout: true).trim()
                    env.LAMBDA_FUNCTION_NAME = sh(script: 'terraform output -raw lambda_function_name', returnStdout: true).trim()
                }
            }
        }
        
        stage('Build and Push Docker Image') {
            steps {
                sh '''
                # Login to ECR
                aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REPOSITORY_URL}
                
                # Build Docker image
                docker build -t ${ECR_REPOSITORY_URL}:${DOCKER_IMAGE_TAG} .
                
                # Push Docker image to ECR
                docker push ${ECR_REPOSITORY_URL}:${DOCKER_IMAGE_TAG}
                '''
            }
        }
        
        stage('Update Lambda Function') {
            steps {
                sh '''
                # Update Lambda function with new container image
                aws lambda update-function-code \
                    --region ${AWS_REGION} \
                    --function-name ${LAMBDA_FUNCTION_NAME} \
                    --image-uri ${ECR_REPOSITORY_URL}:${DOCKER_IMAGE_TAG}
                '''
            }
        }
        
        stage('Test Lambda Function') {
            steps {
                sh '''
                # Create test event file
                cat > test-event.json << EOL
                {
                    "s3_bucket": "$(terraform output -raw s3_bucket_name)",
                    "s3_key": "test-data.csv"
                }
                EOL
                
                # Invoke Lambda function with test event
                aws lambda invoke \
                    --region ${AWS_REGION} \
                    --function-name ${LAMBDA_FUNCTION_NAME} \
                    --payload file://test-event.json \
                    --cli-binary-format raw-in-base64-out \
                    lambda-response.json
                
                # Print the Lambda response
                cat lambda-response.json
                '''
            }
        }
    }
    
    post {
        always {
            // Clean up
            sh 'rm -f test-event.json lambda-response.json'
        }
        success {
            echo 'Pipeline completed successfully!'
        }
        failure {
            echo 'Pipeline failed!'
        }
    }
}
