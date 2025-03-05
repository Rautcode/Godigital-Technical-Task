provider "aws" {
  region = var.aws_region
}

# Ensure the S3 bucket exists before creating a new one
data "aws_s3_bucket" "existing_bucket" {
  bucket = var.s3_bucket_name
}

resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

resource "aws_s3_bucket" "data_bucket" {
  bucket = coalesce(data.aws_s3_bucket.existing_bucket.id, "${var.s3_bucket_name}-${random_string.suffix.result}")
}

resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "data-pipeline-subnet-group"
  subnet_ids = ["subnet-028121377f9e02a1d", "subnet-02b05146f9d302061"]  # Using correct subnets from AWS

  tags = {
    Name = "Data Pipeline RDS subnet group"
  }
}

resource "aws_subnet" "subnet1" {
  vpc_id            = "vpc-00f29f899d9c9dc8d"  # Ensuring correct VPC
  subnet_id         = "subnet-028121377f9e02a1d"
  cidr_block        = "10.0.1.0/24"
  availability_zone = "${var.aws_region}a"

  tags = {
    Name = "data-pipeline-subnet-1"
  }
}

resource "aws_subnet" "subnet2" {
  vpc_id            = "vpc-00f29f899d9c9dc8d"  # Ensuring correct VPC
  subnet_id         = "subnet-02b05146f9d302061"
  cidr_block        = "10.0.2.0/24"
  availability_zone = "${var.aws_region}b"

  tags = {
    Name = "data-pipeline-subnet-2"
  }
}

# Output values
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
