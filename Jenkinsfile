pipeline {
    agent any

    environment {
        AWS_ACCOUNT_ID = '982534379850'       
        AWS_REGION = 'ap-south-1'              
        ECR_REPO = 'my-python-app-lambda'     
        LAMBDA_FUNCTION = 'my-python-app'     
        ECR_URI = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO}"
    }

    stages {
        stage('Clone Repo') {
            steps {
                script {
                    echo "Cloning repository..."
                    checkout([
                        $class: 'GitSCM',
                        branches: [[name: 'refs/heads/main']],  // Force use of main branch
                        userRemoteConfigs: [[url: 'https://github.com/Rautcode/aws-devops-task.git']]
                    ])
                }
            }
        }

        stage('Build Docker Image') {
            steps {
                script {
                    echo "Building Docker image..."
                    // Validate required environment variables
                    if (!env.ECR_REPO || !env.ECR_URI) {
                        error "ECR_REPO or ECR_URI is not defined. Ensure environment variables are set."
                        }
                    powershell '''
                    # Enable BuildKit for improved performance and compatibility
                    $env:DOCKER_BUILDKIT="1"
                    # Build Docker image with platform specification
                    docker build --platform linux/amd64 -t "$env:ECR_URI`:latest" .
                    # Verify the build was successful
                    if ($LASTEXITCODE -ne 0) {
                    Write-Host "Docker build failed."
                    exit 1
                    }
                    '''
                    }
                }
            }
        stage('Login to AWS ECR') {
            steps {
                script {
                    withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'AWS']]) {
                        echo "Logging into AWS ECR..."
                        powershell '''
                        $PASSWORD = aws ecr get-login-password --region ap-south-1
                        $PASSWORD | docker login --username AWS --password-stdin 982534379850.dkr.ecr.ap-south-1.amazonaws.com
                        '''
                    }
                }
            }
        }

        stage('Ensure ECR Repository Exists') {
            steps {
                script {
                    echo "Checking if ECR repository exists..."
                    def ecrExists = powershell(returnStatus: true, script: "aws ecr describe-repositories --repository-names ${ECR_REPO} --region ${AWS_REGION}")

                    if (ecrExists != 0) {
                        echo "ECR repository does not exist. Creating..."
                        powershell "aws ecr create-repository --repository-name ${ECR_REPO} --region ${AWS_REGION}"
                    } else {
                        echo "ECR repository already exists."
                    }
                }
            }
        }

        stage('Tag and Push Docker Image') {
            steps {
                script {
                    echo "Tagging Docker image..."
                    powershell "docker tag ${ECR_REPO}:latest ${ECR_URI}:latest"

                    echo "Pushing Docker image to ECR..."
                    powershell "docker push ${ECR_URI}:latest"
                }
            }
        }

        stage('Deploy to AWS Lambda') {
            steps {
                script {
                    
                    echo "Updating AWS Lambda function..."
                    powershell "aws lambda update-function-code --function-name ${LAMBDA_FUNCTION} --image-uri ${ECR_URI}:latest"
                }
            }
        }
    }
}
