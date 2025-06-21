variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "dag_bucket_name" {
  description = "S3 bucket name for MWAA DAGs"
  type        = string
  default     = "pranai-mwaa-dags"
}

variable "output_bucket_name" {
  description = "S3 bucket name for output data"
  type        = string
  default     = "pranai-twitter-output"
}

variable "subnet_ids" {
  description = "List of subnet IDs for MWAA"
  type        = list(string)
}

variable "security_group_id" {
  description = "Security group ID for MWAA"
  type        = string
}

variable "twitter_bearer_token" {
  description = "Twitter API Bearer Token"
  type        = string
  sensitive   = true
}