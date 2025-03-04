variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "s3_bucket_name" {
  description = "Name of the S3 bucket for data storage"
  type        = string
  default     = "data-pipeline-bucket"
}

variable "rds_db_name" {
  description = "Name of the RDS database"
  type        = string
  default     = "datapipeline"
}

variable "rds_username" {
  description = "Username for RDS database"
  type        = string
  default     = "dbadmin"
}

variable "rds_password" {
  description = "Password for RDS database"
  type        = string
  sensitive   = true
}

variable "glue_db_name" {
  description = "Name of the AWS Glue database"
  type        = string
  default     = "datapipeline"
}

variable "ecr_repo_name" {
  description = "Name of the ECR repository"
  type        = string
  default     = "data-pipeline-repo"
}

variable "lambda_function_name" {
  description = "Name of the Lambda function"
  type        = string
  default     = "data-pipeline-function"
}