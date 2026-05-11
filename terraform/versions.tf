terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

# Default provider for your normal app resources
# S3, Lambda, API Gateway, DynamoDB, etc.
provider "aws" {
  region = "eu-west-1"
}

# Special provider only for CloudFront ACM certificates
# CloudFront requires ACM certificates to be in us-east-1
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}