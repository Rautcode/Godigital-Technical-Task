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
                checkout scm
            }
        }

        stage('Terraform Init') {
            steps {
                sh 'terraform init'
            }
        }

        stage('Check & Import Existing Resources') {
            steps {
                script {
                    def resources = [
                        ["aws_ecr_repository.ecr_repo", "982534379850.dkr.ecr.us-east-1.amazonaws.com/data-pipeline-repo"],
                        ["aws_iam_role.lambda_role", "lambda_execution_role"],
                        ["aws_glue_catalog_database.glue_db", "datapipeline"],
                        ["aws_db_subnet_group.rds_subnet_group", "data-pipeline-subnet-group"]
                    ]

                    for (res in resources) {
                        def (resource, id) = res
                        def exists = sh(script: "terraform state list | grep ${resource}", returnStatus: true)
                        if (exists != 0) {
                            sh "terraform import ${resource} ${id}"
                        }
                    }
                }
            }
        }

        stage('Terraform Plan & Apply') {
            steps {
                sh '''
                terraform plan -out=tfplan
                terraform apply -auto-approve tfplan
                '''
            }
        }

        stage('Push Docker Image to AWS ECR') {
            steps {
                sh '''
                aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REPOSITORY_URL}
                docker tag my-docker-image:latest ${ECR_REPOSITORY_URL}:${DOCKER_IMAGE_TAG}
                docker push ${ECR_REPOSITORY_URL}:${DOCKER_IMAGE_TAG}
                '''
            }
        }

        stage('Update Lambda Function') {
            steps {
                sh '''
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
                cat > test-event.json << EOL
                {
                    "s3_bucket": "${S3_BUCKET_NAME}",
                    "s3_key": "test-data.csv"
                }
                EOL

                aws lambda invoke \
                --region ${AWS_REGION} \
                --function-name ${LAMBDA_FUNCTION_NAME} \
                --payload file://test-event.json \
                --cli-binary-format raw-in-base64-out \
                lambda-response.json

                cat lambda-response.json
                '''
            }
        }
    }

    post {
        always {
            sh 'rm -f test-event.json lambda-response.json || true'
        }
        success {
            echo 'Jenkins Pipeline completed successfully!'
        }
        failure {
            echo 'Jenkins Pipeline failed! Check logs for details.'
        }
    }
}
