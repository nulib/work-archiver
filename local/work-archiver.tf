module "work-archiver" {
  source    = "../work-archiver"

  elasticsearch_endpoint            = aws_elasticsearch_domain.local_index.endpoint
  email_access_policy_arn           = "arn:aws:iam::000000000000:policy/email"
  elasticsearch_access_policy_arn   = "arn:aws:iam::000000000000:policy/index"
  environment                       = "local"
  index                             = "meadow"
  sender_email                      = "work-archiver@northwestern.edu"
}

output "api_endpoint" {
  value = module.work-archiver.api_endpoint
}