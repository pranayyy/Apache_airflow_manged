provider "aws" {
  region = var.aws_region
}

# S3 bucket for DAGs
resource "aws_s3_bucket" "dag_bucket" {
  bucket        = var.dag_bucket_name
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "dag_bucket_versioning" {
  bucket = aws_s3_bucket.dag_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "dag_bucket_pab" {
  bucket = aws_s3_bucket.dag_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 bucket for output data
resource "aws_s3_bucket" "output_bucket" {
  bucket        = var.output_bucket_name
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "output_bucket_versioning" {
  bucket = aws_s3_bucket.output_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "output_bucket_pab" {
  bucket = aws_s3_bucket.output_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# IAM role for MWAA
resource "aws_iam_role" "mwaa_execution_role" {
  name = "mwaa-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "airflow.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

# Custom policy for MWAA to access S3 buckets
resource "aws_iam_policy" "mwaa_s3_policy" {
  name = "mwaa-s3-policy"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ],
        Resource = [
          aws_s3_bucket.dag_bucket.arn,
          "${aws_s3_bucket.dag_bucket.arn}/*",
          aws_s3_bucket.output_bucket.arn,
          "${aws_s3_bucket.output_bucket.arn}/*"
        ]
      }
    ]
  })
}

# Attach policies to MWAA role
resource "aws_iam_role_policy_attachment" "mwaa_policy" {
  role       = aws_iam_role.mwaa_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/aws-service-role/AmazonMWAAServicePolicy"
}

resource "aws_iam_role_policy_attachment" "mwaa_s3_policy" {
  role       = aws_iam_role.mwaa_execution_role.name
  policy_arn = aws_iam_policy.mwaa_s3_policy.arn
}

# MWAA Environment
resource "aws_mwaa_environment" "twitter_env" {
  name                  = "twitter-etl"
  airflow_version       = "2.9.2"
  dag_s3_path           = "dags"
  source_bucket_arn     = aws_s3_bucket.dag_bucket.arn
  execution_role_arn    = aws_iam_role.mwaa_execution_role.arn
  environment_class     = "mw1.small"
  webserver_access_mode = "PUBLIC_ONLY"

  network_configuration {
    security_group_ids = [var.security_group_id]
    subnet_ids         = var.subnet_ids
  }

  airflow_configuration_options = {
    "core.default_timezone"   = "UTC"
    "webserver.expose_config" = "True"
  }

  tags = {
    Environment = "production"
    Project     = "twitter-etl"
  }
}