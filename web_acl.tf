resource "aws_wafv2_regex_pattern_set" "work_archiver" {
  name        = "work-archiver-referer-patterns"
  description = "Pattern set to match to Meadow, DC and devbox domains"
  scope       = "REGIONAL"
  regular_expression {
    regex_string = "(devbox|digitalcollections|meadow|dc)\\.(rdc(-staging)?\\.)?library\\.northwestern\\.edu(:3001)?"
  }
  tags = var.tags

}


resource "aws_wafv2_web_acl" "work_archiver" {
  name        = "work-archiver-referers-web-acl"
  description = "Only allow requests from Meadow, DC or devbox."
  scope       = "REGIONAL"

  default_action {
    block {}
  }

  rule {
    name     = "work-archiver-referer-match-rule"
    priority = 0

    action {
      allow {}
    }

    statement {
      regex_pattern_set_reference_statement {
        arn = aws_wafv2_regex_pattern_set.work_archiver.arn
        field_to_match {
          single_header {
            name = "referer"
          }
        }
        text_transformation {
          priority = 1
          type     = "NONE"
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.stack_name}-rule-metric"
      sampled_requests_enabled   = true
    }
  }

  tags = var.tags

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.stack_name}-web-acl-metric"
    sampled_requests_enabled   = true
  }
}
