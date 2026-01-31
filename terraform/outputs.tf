output "beta_bucket_name" {
  description = "Name of the beta S3 bucket"
  value       = aws_s3_bucket.beta.id
}

output "beta_bucket_arn" {
  description = "ARN of the beta S3 bucket"
  value       = aws_s3_bucket.beta.arn
}

output "beta_bucket_regional_domain_name" {
  description = "Regional domain name of the beta bucket"
  value       = aws_s3_bucket.beta.bucket_regional_domain_name
}

output "prod_bucket_name" {
  description = "Name of the production S3 bucket"
  value       = aws_s3_bucket.prod.id
}

output "prod_bucket_arn" {
  description = "ARN of the production S3 bucket"
  value       = aws_s3_bucket.prod.arn
}

output "prod_bucket_regional_domain_name" {
  description = "Regional domain name of the production bucket"
  value       = aws_s3_bucket.prod.bucket_regional_domain_name
}

output "beta_website_endpoint" {
  description = "Website endpoint for beta bucket (if enabled)"
  value       = var.enable_website_hosting ? aws_s3_bucket_website_configuration.beta[0].website_endpoint : null
}

output "prod_website_endpoint" {
  description = "Website endpoint for production bucket (if enabled)"
  value       = var.enable_website_hosting ? aws_s3_bucket_website_configuration.prod[0].website_endpoint : null
}

output "deployment_summary" {
  description = "Summary of deployed resources"
  value = {
    beta_bucket = {
      name            = aws_s3_bucket.beta.id
      region          = var.aws_region
      versioning      = "Enabled"
      encryption      = "AES256"
      public_access   = var.enable_public_access
      website_hosting = var.enable_website_hosting
    }
    prod_bucket = {
      name            = aws_s3_bucket.prod.id
      region          = var.aws_region
      versioning      = "Enabled"
      encryption      = "AES256"
      public_access   = var.enable_public_access
      website_hosting = var.enable_website_hosting
    }
  }
}
