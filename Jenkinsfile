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
                    env.S3_BUCKET_NAME = sh(script: 'terraform output -raw s3_bucket_name', returnStdout: true).trim()
                }
            }
        }
        
        stage('Build OCI Image') {
            steps {
                sh '''
                # Build Docker image in OCI format
                docker buildx build --output type=oci,dest=oci-image.tar .
                '''
            }
        }

        stage('Convert OCI to Docker V2') {
            steps {
                script {
                    sh '''
                    wsl skopeo copy oci-archive:oci-image.tar docker-archive:docker-image.tar
                    '''
                    }
                }
            }
        
        stage('Push Docker Image to AWS ECR') {
            steps {
                sh '''
                # Extract the repository name from the URL
                REPO_NAME=$(echo ${ECR_REPOSITORY_URL} | awk -F'/' '{print $NF}')
                
                # Login to ECR
                aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REPOSITORY_URL}
                
                # Tag and push Docker image to ECR
                docker tag ${REPO_NAME}:${DOCKER_IMAGE_TAG} ${ECR_REPOSITORY_URL}:${DOCKER_IMAGE_TAG}
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
                    "s3_bucket": "${S3_BUCKET_NAME}",
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
            sh 'rm -f test-event.json lambda-response.json'
        }
        success {
            echo '✅ Pipeline completed successfully!'
        }
        failure {
            echo '❌ Pipeline failed! Check logs.'
        }
    }
}
