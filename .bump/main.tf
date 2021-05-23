terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "3.30.0"
    }
  }
}

# Don't put credentials here, instead export them as
# AWS_ACCESS_KEY and AWS_SECRET_KEY
provider "aws" {
  region = "us-east-1"
}

locals {
  changelog_filename = "changelog.xml"
  changelog_api_filename = "changelog.json"
  s3_bucket_name = yamldecode(file("../config.yml"))["s3_bucket_name"]
  app_filename = yamldecode(file("../config.yml"))["app_filename"]
  app_version = yamldecode(file(".state/latestRelease"))["version"]
}

# Start creating resources
# To deprovision resources in the future, remove everything below this commment and run `terraform apply`
resource "aws_s3_bucket" "bucket" {
  bucket = local.s3_bucket_name
  acl    = "private"

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET"]
    allowed_origins = ["*"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

resource "aws_s3_bucket_object" "changelog" {
  bucket = local.s3_bucket_name
  key    = local.changelog_filename
  source = "../release/${local.changelog_filename}"
  etag   = filemd5("../release/${local.changelog_filename}")
  acl    = "public-read"
  content_type = "application/xml"

  depends_on = [
    aws_s3_bucket.bucket,
  ]
}

resource "aws_s3_bucket_object" "changelog_api" {
  bucket = local.s3_bucket_name
  key    = local.changelog_api_filename
  source = "../release/${local.changelog_api_filename}"
  etag   = filemd5("../release/${local.changelog_api_filename}")
  acl    = "public-read"
  content_type = "application/json"

  depends_on = [
    aws_s3_bucket.bucket,
  ]
}

resource "aws_s3_bucket_object" "versioned_zip" {
  bucket = local.s3_bucket_name
  key    = "${replace(local.app_version, ".", "-")}/${local.app_filename}"
  source = "../release/${local.app_filename}"
  etag   = filemd5("../release/${local.app_filename}")
  acl    = "public-read"
  content_type = "application/octet-stream"

  depends_on = [
    aws_s3_bucket.bucket,
  ]
}

resource "aws_s3_bucket_object" "latest_zip" {
  bucket = local.s3_bucket_name
  key    = "latest/${local.app_filename}"
  source = "../release/${local.app_filename}"
  etag   = filemd5("../release/${local.app_filename}")
  acl    = "public-read"
  content_type = "application/octet-stream"

  depends_on = [
    aws_s3_bucket.bucket,
  ]
}

output "changelog_public_url" {
  description = "The URL for the changelog.xml file"
  value       = "https://${aws_s3_bucket.bucket.bucket_domain_name}/${local.changelog_filename}"
}
