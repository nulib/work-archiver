output "api_endpoint" {
  value = aws_apigatewayv2_stage.work_archiver.invoke_url
}
