output "mwaa_web_url" {
  description = "MWAA Webserver URL"
  value       = aws_mwaa_environment.twitter_env.webserver_url
}

output "dag_bucket_name" {
  description = "DAG S3 bucket name"
  value       = aws_s3_bucket.dag_bucket.bucket
}

output "output_bucket_name" {
  description = "Output S3 bucket name"
  value       = aws_s3_bucket.output_bucket.bucket
}

output "mwaa_environment_name" {
  description = "MWAA Environment name"
  value       = aws_mwaa_environment.twitter_env.name
}