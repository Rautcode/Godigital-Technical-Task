pipeline {
    agent any

    environment {
        AWS_REGION = 'us-east-1'
        ECR_REPO_NAME = 'data-pipeline-repo'
        DOCKER_IMAGE_TAG = 'latest'
        TF_VAR_rds_password = credentials('rds-password')
    }

    stages {
        stage('Checkout Code') {
            steps {
                script {
                    echo 'Checking out source code...'
                }
                checkout scm
            }
        }

        stage('Verify Dependencies') {
            steps {
                script {
                    echo 'Verifying Terraform, AWS CLI, and Docker installation...'
                }
                sh '''
                terraform -version || { echo "ERROR: Terraform is not installed!"; exit 1; }
                aws --version || { echo "ERROR: AWS CLI is not installed!"; exit 1; }
                docker --version || { echo "ERROR: Docker is not installed!"; exit 1; }
                '''
            }
        }

        stage('Terraform Init & Apply') {
            steps {
                script {
                    echo 'Initializing and applying Terraform configuration...'
                }
                sh '''
                terraform init
                terraform plan -out=tfplan
                terraform apply -auto-approve tfplan
                '''

                script {
                    echo 'Fetching Terraform outputs...'
                    def ecr_output = sh(script: 'terraform output -raw ecr_repository_url || echo "ERROR"', returnStdout: true).trim()
                    def lambda_output = sh(script: 'terraform output -raw lambda_function_name || echo "ERROR"', returnStdout: true).trim()
                    def s3_output = sh(script: 'terraform output -raw s3_bucket_name || echo "ERROR"', returnStdout: true).trim()

                    if (ecr_output == "ERROR" || lambda_output == "ERROR" || s3_output == "ERROR") {
                        error "ERROR: Terraform outputs could not be retrieved!"
                    }

                    env.ECR_REPOSITORY_URL = ecr_output
                    env.LAMBDA_FUNCTION_NAME = lambda_output
                    env.S3_BUCKET_NAME = s3_output
                }
            }
        }

        stage('Push Docker Image to AWS ECR') {
            steps {
                script {
                    echo 'Logging into AWS ECR and pushing Docker image...'
                }
                sh '''
                aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REPOSITORY_URL}

                echo "Tagging Docker image..."
                docker tag my-docker-image:latest ${ECR_REPOSITORY_URL}:${DOCKER_IMAGE_TAG}

                echo "Pushing Docker image to AWS ECR..."
                docker push ${ECR_REPOSITORY_URL}:${DOCKER_IMAGE_TAG}
                '''
            }
        }

        stage('Update AWS Lambda with New Image') {
            steps {
                script {
                    echo 'Updating AWS Lambda function with new image...'
                }
                sh '''
                aws lambda update-function-code \
                --region ${AWS_REGION} \
                --function-name ${LAMBDA_FUNCTION_NAME} \
                --image-uri ${ECR_REPOSITORY_URL}:${DOCKER_IMAGE_TAG} || { echo "ERROR: Lambda update failed!"; exit 1; }

                echo "Waiting for Lambda to sync new image..."
                sleep 10
                '''
            }
        }

        stage('Invoke & Test AWS Lambda') {
            steps {
                script {
                    echo 'Invoking AWS Lambda function for testing...'
                }
                sh '''
                cat > test-event.json << EOL
                {
                    "s3_bucket": "${S3_BUCKET_NAME}",
                    "s3_key": "test-data.csv"
                }
                EOL

                echo "Running AWS Lambda function test..."
                aws lambda invoke \
                --region ${AWS_REGION} \
                --function-name ${LAMBDA_FUNCTION_NAME} \
                --payload file://test-event.json \
                --cli-binary-format raw-in-base64-out \
                lambda-response.json || { echo "ERROR: Lambda invocation failed!"; exit 1; }

                echo "Lambda function executed successfully. Response:"
                cat lambda-response.json
                '''
            }
        }
    }

    post {
        always {
            script {
                echo 'Cleaning up temporary files...'
            }
            sh 'rm -f test-event.json lambda-response.json'
        }
        success {
            script {
                echo 'Jenkins Pipeline completed successfully!'
            }
        }
        failure {
            script {
                echo 'Jenkins Pipeline failed! Check logs for details.'
            }
        }
    }
}
