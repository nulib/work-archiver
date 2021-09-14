terraform {
  backend "s3" {}
}

data "terraform_remote_state" "work_archiver" {
  backend = "s3"

  config {
    bucket = var.state_bucket
    key = "env:/${terraform.workspace}/${var.project_name}.tfstate"
    region = var.aws_region
  }
}

provider "aws" {
  region = var.region
}

resource "aws_s3_bucket" "work_archiver_bucket" {
  bucket  = "${var.project_name}-${var.environment}-archives"
  acl = "private"
  tags = var.tags

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
    Action    = "s3:*"
        Resource = [
          aws_s3_bucket.work_archiver_bucket.arn,
          "${aws_s3_bucket.work_archiver_bucket.arn}/*",
        ]
  }
}
