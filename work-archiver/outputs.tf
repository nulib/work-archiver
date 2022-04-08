output "api_endpoint" {
  value = aws_apigatewayv2_stage.work_archiver.invoke_url
}

output "work_archiver_api_gateway_stage_arn" {
  value = aws_apigatewayv2_stage.work_archiver.arn
}
