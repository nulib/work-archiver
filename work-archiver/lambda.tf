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

module "lambda_function" {
  source = "terraform-aws-modules/lambda/aws"

  function_name = var.name
  description   = "Creates a .zip archive on S3 of file set assets associated with a work ID. Returns expiring download link via email."
  handler       = "index.handler"
  memory_size   = 4096
  runtime       = "nodejs14.x"
  timeout       = 600
  role          = aws_iam_role.lambda_role.arn
  tags          = var.tags

  source_path = [
    {
      path = "${path.module}/lambda"
      commands = ["npm install --only prod --no-bin-links --no-fund", ":zip"]
    }
  ]

  environment_variables = {
    elasticsearchEndpoint = var.elasticsearch_endpoint,
    archiveBucket         = aws_s3_bucket.work_archiver_bucket.id,
    region                = var.aws_region,
    indexName             = var.index,
    senderEmail           = var.sender_email
  }
}

resource "aws_lambda_function_event_invoke_config" "work_archiver" {
  function_name                = module.lambda_function.lambda_function_name
  maximum_event_age_in_seconds = 360
  maximum_retry_attempts       = 0
}

