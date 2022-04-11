data "aws_iam_policy_document" "lambda_self_invocation" {
  statement {
    effect     = "Allow"
    actions    = ["lambda:InvokeFunction"]
    resources  = ["*"]
  }
}

resource "aws_iam_policy" "lambda_self_invocation" {
  name = "${var.name}-lambda-self-invocation"
  policy = data.aws_iam_policy_document.lambda_self_invocation.json
}

resource "aws_iam_role_policy_attachment" "lambda_self_invocation" {
  role       = module.lambda_function.lambda_role_name
  policy_arn = aws_iam_policy.lambda_self_invocation.arn
}

resource "aws_iam_role_policy_attachment" "lambda_bucket_access" {
  role       = module.lambda_function.lambda_role_name
  policy_arn = aws_iam_policy.work_archiver_bucket_policy.arn
}

resource "aws_iam_role_policy_attachment" "send_email_access" {
  role       = module.lambda_function.lambda_role_name
  policy_arn = var.email_access_policy_arn
}

resource "aws_iam_role_policy_attachment" "elasticsearch_access" {
  role       = module.lambda_function.lambda_role_name
  policy_arn = var.elasticsearch_access_policy_arn
}

resource "aws_ses_email_identity" "sender_email" {
  email = var.sender_email
}

module "lambda_function" {
  source = "terraform-aws-modules/lambda/aws"

  function_name = var.name
  description   = "Creates a .zip archive on S3 of file set assets associated with a work ID. Returns expiring download link via email."
  handler       = "index.handler"
  memory_size   = 4096
  runtime       = "nodejs14.x"
  timeout       = 600
  tags          = var.tags

  source_path = [
    {
      path     = "${path.module}/lambda"
      commands = ["npm install --only prod --no-bin-links --no-fund", ":zip"]
    }
  ]

  environment_variables = {
    allowedReferers       = var.allowed_referers,
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

