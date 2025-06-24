provider "aws" {
  region = var.aws_region
}

# Data source to get available AZs
data "aws_availability_zones" "available" {
  state = "available"
}

# VPC
resource "aws_vpc" "mwaa_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "mwaa-vpc"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "mwaa_igw" {
  vpc_id = aws_vpc.mwaa_vpc.id

  tags = {
    Name = "mwaa-igw"
  }
}

# Public Subnets (for NAT Gateway)
resource "aws_subnet" "public_subnet_1" {
  vpc_id                  = aws_vpc.mwaa_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "mwaa-public-subnet-1"
  }
}

resource "aws_subnet" "public_subnet_2" {
  vpc_id                  = aws_vpc.mwaa_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true

  tags = {
    Name = "mwaa-public-subnet-2"
  }
}

# Private Subnets (for MWAA)
resource "aws_subnet" "private_subnet_1" {
  vpc_id            = aws_vpc.mwaa_vpc.id
  cidr_block        = "10.0.10.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "mwaa-private-subnet-1"
  }
}

resource "aws_subnet" "private_subnet_2" {
  vpc_id            = aws_vpc.mwaa_vpc.id
  cidr_block        = "10.0.11.0/24"
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = {
    Name = "mwaa-private-subnet-2"
  }
}

# Elastic IPs for NAT Gateways
resource "aws_eip" "nat_eip_1" {
  domain = "vpc"
  depends_on = [aws_internet_gateway.mwaa_igw]

  tags = {
    Name = "mwaa-nat-eip-1"
  }
}

resource "aws_eip" "nat_eip_2" {
  domain = "vpc"
  depends_on = [aws_internet_gateway.mwaa_igw]

  tags = {
    Name = "mwaa-nat-eip-2"
  }
}

# NAT Gateways
resource "aws_nat_gateway" "nat_gateway_1" {
  allocation_id = aws_eip.nat_eip_1.id
  subnet_id     = aws_subnet.public_subnet_1.id

  tags = {
    Name = "mwaa-nat-gateway-1"
  }

  depends_on = [aws_internet_gateway.mwaa_igw]
}

resource "aws_nat_gateway" "nat_gateway_2" {
  allocation_id = aws_eip.nat_eip_2.id
  subnet_id     = aws_subnet.public_subnet_2.id

  tags = {
    Name = "mwaa-nat-gateway-2"
  }

  depends_on = [aws_internet_gateway.mwaa_igw]
}

# Route Tables
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.mwaa_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.mwaa_igw.id
  }

  tags = {
    Name = "mwaa-public-rt"
  }
}

resource "aws_route_table" "private_rt_1" {
  vpc_id = aws_vpc.mwaa_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gateway_1.id
  }

  tags = {
    Name = "mwaa-private-rt-1"
  }
}

resource "aws_route_table" "private_rt_2" {
  vpc_id = aws_vpc.mwaa_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gateway_2.id
  }

  tags = {
    Name = "mwaa-private-rt-2"
  }
}

# Route Table Associations
resource "aws_route_table_association" "public_rta_1" {
  subnet_id      = aws_subnet.public_subnet_1.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_rta_2" {
  subnet_id      = aws_subnet.public_subnet_2.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "private_rta_1" {
  subnet_id      = aws_subnet.private_subnet_1.id
  route_table_id = aws_route_table.private_rt_1.id
}

resource "aws_route_table_association" "private_rta_2" {
  subnet_id      = aws_subnet.private_subnet_2.id
  route_table_id = aws_route_table.private_rt_2.id
}

# Security Group for MWAA
resource "aws_security_group" "mwaa_sg" {
  name_prefix = "mwaa-sg"
  vpc_id      = aws_vpc.mwaa_vpc.id

  # Self-referencing rule for internal communication
  ingress {
    from_port = 0
    to_port   = 65535
    protocol  = "tcp"
    self      = true
  }

  # HTTPS outbound for package downloads and API calls
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP outbound for package downloads
  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # PostgreSQL outbound (for MWAA metadata DB)
  egress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Self-referencing egress rule
  egress {
    from_port = 0
    to_port   = 65535
    protocol  = "tcp"
    self      = true
  }

  tags = {
    Name = "mwaa-security-group"
  }
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
        Service = [
          "airflow.amazonaws.com",
          "airflow-env.amazonaws.com"
        ]
      },
      Action = "sts:AssumeRole"
    }]
  })
}

# Custom execution policy for MWAA (combines all required permissions)
resource "aws_iam_policy" "mwaa_execution_policy" {
  name = "mwaa-execution-policy"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = "airflow:PublishMetrics",
        Resource = "arn:aws:airflow:${var.aws_region}:*:environment/twitter-etl"
      },
      {
        Effect = "Deny",
        Action = "s3:ListAllMyBuckets",
        Resource = [
          aws_s3_bucket.dag_bucket.arn,
          "${aws_s3_bucket.dag_bucket.arn}/*"
        ]
      },
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject*",
          "s3:GetBucket*",
          "s3:List*"
        ],
        Resource = [
          aws_s3_bucket.dag_bucket.arn,
          "${aws_s3_bucket.dag_bucket.arn}/*",
          aws_s3_bucket.output_bucket.arn,
          "${aws_s3_bucket.output_bucket.arn}/*"
        ]
      },
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogStream",
          "logs:CreateLogGroup",
          "logs:PutLogEvents",
          "logs:GetLogEvents",
          "logs:GetLogRecord",
          "logs:GetLogGroupFields",
          "logs:GetQueryResults"
        ],
        Resource = [
          "arn:aws:logs:${var.aws_region}:*:log-group:airflow-twitter-etl-*"
        ]
      },
      {
        Effect = "Allow",
        Action = [
          "logs:DescribeLogGroups"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "s3:GetAccountPublicAccessBlock"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = "cloudwatch:PutMetricData",
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "sqs:ChangeMessageVisibility",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:GetQueueUrl",
          "sqs:ReceiveMessage",
          "sqs:SendMessage"
        ],
        Resource = "arn:aws:sqs:${var.aws_region}:*:airflow-celery-*"
      },
      {
        Effect = "Allow",
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:GenerateDataKey*",
          "kms:Encrypt"
        ],
        NotResource = "arn:aws:kms:*:*:key/*",
        Condition = {
          StringLike = {
            "kms:ViaService" = [
              "sqs.${var.aws_region}.amazonaws.com"
            ]
          }
        }
      }
    ]
  })
}

# Attach the execution policy to the role
resource "aws_iam_role_policy_attachment" "mwaa_execution_policy" {
  role       = aws_iam_role.mwaa_execution_role.name
  policy_arn = aws_iam_policy.mwaa_execution_policy.arn
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
    security_group_ids = [aws_security_group.mwaa_sg.id]
    subnet_ids         = [aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id]
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

# Outputs
output "mwaa_webserver_url" {
  description = "The webserver URL of the MWAA Environment"
  value       = aws_mwaa_environment.twitter_env.webserver_url
}

output "mwaa_arn" {
  description = "The ARN of the MWAA Environment"
  value       = aws_mwaa_environment.twitter_env.arn
}

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.mwaa_vpc.id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = [aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id]
}