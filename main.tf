provider "aws" {
  region     = var.aws_region
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}

resource "aws_s3_bucket" "data_bucket" {
  bucket = var.s3_bucket_name
}

resource "aws_s3_bucket_acl" "data_bucket_acl" {
  bucket = aws_s3_bucket.data_bucket.id
  acl    = "private"
}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  
  tags = {
    Name = "data-pipeline-vpc"
  }
}

resource "aws_db_instance" "postgres" {
  allocated_storage    = 20
  engine               = "postgres"
  engine_version       = "14.6"
  instance_class       = "db.t3.micro"
  db_name              = var.rds_db_name
  username             = var.rds_username
  password             = var.rds_password
  skip_final_snapshot  = true
  
  tags = {
    Name = "data-pipeline-postgres"
  }
}

resource "aws_glue_catalog_database" "glue_db" {
  name = var.glue_db_name
}
resource "aws_ecr_repository" "ecr_repo" {
  name                 = var.ecr_repo_name
  image_tag_mutability = "MUTABLE"
}
data "aws_caller_identity" "current" {}

output "lambda_function_name" {
  value = aws_lambda_function.data_pipeline_lambda.function_name
}

output "ecr_repository_url" {
  value = aws_ecr_repository.ecr_repo.repository_url
}

output "s3_bucket_name" {
  value = aws_s3_bucket.data_bucket.bucket
}

output "rds_endpoint" {
  value = aws_db_instance.postgres.address
}

output "glue_database_name" {
  value = aws_glue_catalog_database.glue_db.name
}
