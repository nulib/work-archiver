resource "aws_elasticsearch_domain" "local_index" {
  domain_name           = "local"
  elasticsearch_version = "7.10"
}

data "aws_iam_policy_document" "index_read_access" {
  statement {
    effect    = "Allow"
    actions   = ["es:ESHttpGet"]
    resources = [
      aws_elasticsearch_domain.local_index.arn,
      "${aws_elasticsearch_domain.local_index.arn}/*"
    ]
  }
}

resource "aws_iam_policy" "index_read_access" {
  name   = "elasticsearch-read"
  policy = data.aws_iam_policy_document.index_read_access.json
}

data "aws_iam_policy_document" "email_access" {
  statement {
    effect    = "Allow"
    actions   = ["ses:*"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "email_access" {
  name   = "send-email"
  policy = data.aws_iam_policy_document.email_access.json
}

