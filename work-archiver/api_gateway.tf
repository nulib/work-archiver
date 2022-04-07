data "template_file" "api_gateway_definition" {
  filename = "${path.module}/api_gateway_definition.yml"
  vars = {
    lambda_invocation_arn = module.lambda_function.lambda_function_invoke_arn
  }
}

resource "aws_api_gateway_rest_api" "work_archiver" {
  body = data.template_file.api_gateway_definition.rendered
  name = "stack-${var.environment}-work-archiver"

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_deployment" "work_archiver" {
  rest_api_id = aws_api_gateway_rest_api.work_archiver.id

  triggers = {
    redeployment = sha1(jsonencode(aws_api_gateway_rest_api.work_archiver.body))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "work_archiver" {
  deployment_id = aws_api_gateway_deployment.work_archiver.id
  rest_api_id   = aws_api_gateway_rest_api.work_archiver.id
  stage_name    = "latest"
}

resource "aws_lambda_permission" "allow_api_gateway_invocation" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.work_archiver.arn
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.work_archiver.execution_arn}/*/POST/archiver"

  lifecycle {
    create_before_destroy = true
  }
}

