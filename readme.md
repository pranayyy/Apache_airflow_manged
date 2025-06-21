# Twitter ETL Pipeline

Automated ETL pipeline for Twitter data using Apache Airflow (MWAA), deployed with Terraform and GitHub Actions.

## Architecture

- **Data Source**: Twitter API v2
- **Orchestration**: Amazon Managed Workflows for Apache Airflow (MWAA)
- **Storage**: Amazon S3
- **Infrastructure**: Terraform
- **CI/CD**: GitHub Actions

## Setup Instructions

### 1. Prerequisites
- AWS Account with appropriate permissions
- Twitter Developer Account with Bearer Token
- GitHub repository

### 2. Manual Setup (One-time)

#### Create Terraform State Bucket
```bash
aws s3 mb s3://pranai-terraform-state --region us-east-1
aws s3api put-bucket-versioning --bucket pranai-terraform-state --versioning-configuration Status=Enabled