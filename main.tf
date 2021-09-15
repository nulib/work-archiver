terraform {
  backend "s3" {
    key    = "work-archiver.tfstate"
    region = "us-east-1"
  }
}


provider "aws" {
  region = var.aws_region
}

resource "aws_s3_bucket" "work_archiver_bucket" {
  bucket = "${var.stack_name}-${var.environment}-archives"
  acl    = "private"
  tags   = var.tags

  lifecycle_rule {
    enabled = true
    expiration {
      days = 1
    }
  }
}

data "aws_iam_policy_document" "work_archiver_bucket_access" {
  statement {
    effect = "Allow"

    actions = [
      "s3:ListBucket",
      "s3:GetBucketLocation"
    ]

    resources = [aws_s3_bucket.work_archiver_bucket.arn]
  }
  statement {
    effect = "Allow"

    actions = [
      "s3:PutObject",
      "s3:PutObjectAcl",
      "s3:GetObject",
      "s3:DeleteObject",
    ]

    resources = ["${aws_s3_bucket.work_archiver_bucket.arn}/*"]
  }
}

resource "aws_iam_policy" "work_archiver_bucket_policy" {
  name   = "work-archiver-bucket-access"
  policy = data.aws_iam_policy_document.work_archiver_bucket_access.json
}
