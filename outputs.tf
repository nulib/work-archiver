output "api_endpoint" {
  value = aws_api_gateway_stage.work_archiver.invoke_url
}
