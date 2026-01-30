# Terraform Backend Configuration
#
# Uncomment and configure this block to use remote state storage
# This is recommended for team environments
#
terraform {
  backend "s3" {
    bucket         = "ec2-shutdown-lambda-bucket"
    key            = "prompt-pipeline/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "dyning-table"
  }
}
