module "work-archiver" {
  source    = "../work-archiver"

  aws_region                        = var.aws_region
  elasticsearch_endpoint            = var.elasticsearch_endpoint
  email_access_policy_arn           = var.email_access_policy_arn
  elasticsearch_access_policy_arn   = var.elasticsearch_access_policy_arn
  environment                       = var.environment
  index                             = var.index
  name                              = var.name
  sender_email                      = var.sender_email
  stack_name                        = var.stack_name
  tags                              = var.tags
}

output "api_endpoint" {
  value = module.work-archiver.api_endpoint
}