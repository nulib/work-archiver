resource "aws_s3_bucket" "work_archiver_bucket" {
  bucket = "${var.stack_name}-${var.environment}-archives"
  tags   = var.tags
}

resource "aws_s3_bucket_acl" "work_archiver_bucket_acl" {
  bucket = aws_s3_bucket.work_archiver_bucket.id
  acl    = "private"
}

resource "aws_s3_bucket_lifecycle_configuration" "work_archiver_bucket_lifecycle" {
  bucket = aws_s3_bucket.work_archiver_bucket.id

  rule {
    id        = "expiration"
    status    = "Enabled"

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
      "s3:GetBucketLocation",
      "s3:GetLifecycleConfiguration",
      "s3:PutLifecycleConfiguration"
    ]

    resources = [aws_s3_bucket.work_archiver_bucket.arn]
  }
  statement {
    effect = "Allow"

    actions = [
      "s3:GetObject",
      "s3:GetObjectAcl",
      "s3:GetObjectVersion",
      "s3:PutObject",
      "s3:PutObjectAcl",
      "s3:DeleteObject",
      "s3:DeleteObjectTagging",
      "s3:DeleteObjectVersionTagging",
      "s3:GetObjectTagging",
      "s3:GetObjectVersionTagging",
      "s3:PutObjectTagging",
      "s3:PutObjectVersionTagging"
    ]

    resources = ["${aws_s3_bucket.work_archiver_bucket.arn}/*"]
  }
}

resource "aws_iam_policy" "work_archiver_bucket_policy" {
  name   = "work-archiver-bucket-access"
  policy = data.aws_iam_policy_document.work_archiver_bucket_access.json
}

