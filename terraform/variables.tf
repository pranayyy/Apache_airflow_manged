variable "aws_region" {
  default = "us-east-1"
}

variable "dag_bucket_name" {
  default = "pranai-mwaa-dags"
}

variable "output_bucket_name" {
  default = "pranai-twitter-output"
}

variable "subnet_ids" {
  type = list(string)
}

variable "security_group_id" {
  type = string
}