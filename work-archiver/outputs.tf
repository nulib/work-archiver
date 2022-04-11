# Compensate for the fact that AWS includes the https:// in the API Gateway V2 ApiEndpoing
# and LocalStack does not.
locals {
  api_endpoint = replace(
    "https://${aws_apigatewayv2_api.work_archiver.api_endpoint}/${aws_apigatewayv2_stage.work_archiver.name}",
    "https://https://",
    "https://"
  )
}

output "api_endpoint" {
  value = local.api_endpoint
}

output "work_archiver_api_gateway_stage_arn" {
  value = aws_apigatewayv2_stage.work_archiver.arn
}
