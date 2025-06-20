provider "aws" {
  region = var.aws_region
}

resource "aws_s3_bucket" "dag_bucket" {
  bucket = var.dag_bucket_name
  force_destroy = true
}

resource "aws_s3_bucket" "output_bucket" {
  bucket = var.output_bucket_name
  force_destroy = true
}

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

resource "aws_iam_role_policy_attachment" "mwaa_policy" {
  role       = aws_iam_role.mwaa_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonMWAAWebServerAccess"
}

resource "aws_mwaa_environment" "twitter_env" {
  name                = "twitter-etl"
  airflow_version     = "2.9.2"
  dag_s3_path         = "dags"
  source_bucket_arn   = aws_s3_bucket.dag_bucket.arn
  execution_role_arn  = aws_iam_role.mwaa_execution_role.arn
  environment_class   = "mw1.small"
  webserver_access_mode = "PUBLIC_ONLY"

  network_configuration {
    security_group_ids = [var.security_group_id]
    subnet_ids         = var.subnet_ids
  }
}