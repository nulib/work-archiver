data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "lambda_role" {
  name               = "${var.stack_name}-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
  tags               = var.tags
}


resource "aws_iam_role_policy_attachment" "lambda_bucket_access" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.work_archiver_bucket_policy.arn
}

resource "aws_iam_role_policy_attachment" "cloudwatch_log_access" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "send_email_access" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::${data.aws_caller_identity.current.id}:policy/stack-${var.environment}-send-email"
}

resource "aws_iam_role_policy_attachment" "elasticsearch_access" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::${data.aws_caller_identity.current.id}:policy/stack-${var.environment}-elasticsearch-access"
}

locals {
  dest_path   = "${path.module}/_build"
  source_path = "${path.module}/lambda"
}

data "archive_file" "source" {
  type        = "zip"
  source_dir  = "${local.source_path}/${var.name}"
  excludes    = ["node_modules"]
  output_path = "${local.dest_path}/${var.name}.src.zip"
}

data "external" "this_zip" {
  program = ["${path.module}/build_lambda.sh"]
  query = {
    name        = var.name
    source_sha  = data.archive_file.source.output_sha
    source_path = local.source_path
    dest_path   = local.dest_path
  }
}


resource "aws_lambda_function" "work_archiver" {
  function_name = var.name
  filename      = data.external.this_zip.result.zip
  description   = "Creates a .zip archive on S3 of file set assets associated with a work ID. Returns expiring download link via email."
  handler       = "index.handler"
  memory_size   = 4096
  runtime       = "nodejs14.x"
  timeout       = 600
  role          = aws.iam_role.lambda_role
  tags          = var.tags


  environment {
    variables = {
      elasticsearchEndpoint = var.elasticsearch_endpoint,
      bucket                = aws_s3_bucket.work_archiver_bucket.name,
      region                = var.region,
      index                 = var.index,
      senderEmail           = var.sender_email
    }
  }
}
