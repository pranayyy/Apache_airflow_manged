terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket = "pranai-terraform-state"
    key    = "twitter-etl/terraform.tfstate"
    region = "us-east-1"

    # Optional: Enable state locking with DynamoDB
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}