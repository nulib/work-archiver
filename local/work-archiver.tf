module "work-archiver" {
  source    = "../work-archiver"

  elasticsearch_endpoint            = aws_elasticsearch_domain.local_index.endpoint
  email_access_policy_arn           = aws_iam_policy.email_access.arn
  elasticsearch_access_policy_arn   = aws_iam_policy.index_read_access.arn
  environment                       = "local"
  index                             = "meadow"
  sender_email                      = "work-archiver@northwestern.edu"
}

output "api_endpoint" {
  value = module.work-archiver.api_endpoint
}