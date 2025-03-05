pipeline {
    agent any

    environment {
        AWS_REGION = 'us-east-1'
        ECR_REPO_NAME = 'data-pipeline-repo'
        DOCKER_IMAGE_TAG = 'latest'
        ECR_REPOSITORY_URL = "982534379850.dkr.ecr.us-east-1.amazonaws.com/${ECR_REPO_NAME}"
        LAMBDA_FUNCTION_NAME = 'data-pipeline-lambda'
        S3_BUCKET_NAME = 'data-pipeline-bucket'
        AWS_ACCESS_KEY_ID = credentials('aws-access-key')
        AWS_SECRET_ACCESS_KEY = credentials('aws-secret-key')

       
        TF_VAR_aws_access_key = credentials('aws-access-key')
        TF_VAR_aws_secret_key = credentials('aws-secret-key')

        
        TF_VAR_rds_password = credentials('rds-password')
    }

    stages {
        stage('Checkout Code') {
            steps {
                git branch: 'main', url: 'https://github.com/Rautcode/Godigital-Technical-Task.git'
            }
        }

        stage('Setup AWS Credentials') {
            steps {
                sh '''
                echo "Configuring AWS CLI..."
                export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
                export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
                aws configure set aws_access_key_id ${AWS_ACCESS_KEY_ID}
                aws configure set aws_secret_access_key ${AWS_SECRET_ACCESS_KEY}
                aws configure set region ${AWS_REGION}
                aws s3 ls
                '''
            }
        }

        stage('Terraform Init') {
            steps {
                sh '''
                echo "Initializing Terraform..."
                terraform init
                '''
            }
        }

        stage('Check & Import Existing Resources') {
            steps {
                script {
                    def resources = [
                        ["aws_ecr_repository.ecr_repo", "${ECR_REPOSITORY_URL}"],
                        ["aws_iam_role.lambda_role", "lambda_execution_role"],
                        ["aws_glue_catalog_database.glue_db", "datapipeline"],
                        ["aws_db_subnet_group.rds_subnet_group", "data-pipeline-subnet-group"]
                    ]

                    for (res in resources) {
                        def (resource, id) = res
                        def exists = sh(script: "terraform state list | grep ${resource}", returnStatus: true)
                        if (exists != 0) {
                            sh '''
                            terraform import ${resource} ${id}
                            '''
                        }
                    }
                }
            }
        }

        stage('Terraform Plan & Apply') {
            steps {
                sh '''
                echo "Running Terraform Plan..."
                terraform plan -out=tfplan

                echo "Applying Terraform Changes..."
                terraform apply -auto-approve tfplan
                '''
            }
        }

        stage('Push Docker Image to AWS ECR') {
            steps {
                sh '''
                echo "Logging into AWS ECR..."
                aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REPOSITORY_URL}

                echo "Building and pushing Docker image..."
                docker build -t ${ECR_REPO_NAME}:latest .
                docker tag ${ECR_REPO_NAME}:latest ${ECR_REPOSITORY_URL}:${DOCKER_IMAGE_TAG}
                docker push ${ECR_REPOSITORY_URL}:${DOCKER_IMAGE_TAG}
                '''
            }
        }

        stage('Update Lambda Function') {
            steps {
                sh '''
                echo "Updating AWS Lambda function..."
                aws lambda update-function-code \
                --region ${AWS_REGION} \
                --function-name ${LAMBDA_FUNCTION_NAME} \
                --image-uri ${ECR_REPOSITORY_URL}:${DOCKER_IMAGE_TAG}
                '''
            }
        }

        stage('Invoke & Test AWS Lambda') {
            steps {
                sh '''
                echo "Creating test event for Lambda..."
                cat > test-event.json << EOL
                {
                    "s3_bucket": "${S3_BUCKET_NAME}",
                    "s3_key": "test-data.csv"
                }
                EOL

                echo "Invoking Lambda function..."
                aws lambda invoke \
                --region ${AWS_REGION} \
                --function-name ${LAMBDA_FUNCTION_NAME} \
                --payload file://test-event.json \
                --cli-binary-format raw-in-base64-out \
                lambda-response.json

                echo "Lambda Response:"
                cat lambda-response.json
                '''
            }
        }
    }

    post {
        always {
            echo "Cleaning up temporary files..."
            sh 'rm -f test-event.json lambda-response.json || true'
        }
        success {
            echo " Jenkins Pipeline completed successfully!"
        }
        failure {
            echo " Jenkins Pipeline failed! Check logs for details."
        }
    }
}
