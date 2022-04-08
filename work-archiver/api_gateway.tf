data "template_file" "api_gateway_definition" {
  template = file("${path.module}/api_gateway_definition.yml")
  vars = {
    lambda_invocation_arn = module.lambda_function.lambda_function_invoke_arn
  }
}

resource "aws_apigatewayv2_api" "work_archiver" {
  name          = "stack-${var.environment}-work-archiver"
  protocol_type = "HTTP"
  body          = data.template_file.api_gateway_definition.rendered
}

resource "aws_apigatewayv2_deployment" "work_archiver" {
  api_id = aws_apigatewayv2_api.work_archiver.id

  triggers = {
    redeployment = sha1(data.template_file.api_gateway_definition.rendered)
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_cloudwatch_log_group" "work-archiver" {
  name = "work-archiver"
}

resource "aws_apigatewayv2_stage" "work_archiver" {
  deployment_id = aws_apigatewayv2_deployment.work_archiver.id
  api_id        = aws_apigatewayv2_api.work_archiver.id
  name          = "latest"
  access_log_settings {
    format          = "$context.identity.sourceIp $context.identity.caller $context.identity.user [$context.requestTime] $context.httpMethod $context.resourcePath $context.protocol $context.status $context.responseLength $context.requestId $context.extendedRequestId"
    destination_arn = aws_cloudwatch_log_group.work-archiver.arn
  }

  route_settings {
    route_key     = "POST /archiver"
    logging_level = "INFO"
  }
}

resource "aws_lambda_permission" "allow_api_gateway_invocation" {
  action        = "lambda:InvokeFunction"
  function_name = module.lambda_function.lambda_function_arn
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.work_archiver.execution_arn}/*/POST/archiver"

  lifecycle {
    create_before_destroy = true
  }
}

