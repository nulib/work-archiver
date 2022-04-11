output "api_endpoint" {
  value = "https://${aws_apigatewayv2_api.work_archiver.api_endpoint}/${aws_apigatewayv2_stage.work_archiver.name}"
}

output "work_archiver_api_gateway_stage_arn" {
  value = aws_apigatewayv2_stage.work_archiver.arn
}
