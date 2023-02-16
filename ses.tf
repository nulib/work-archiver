resource "aws_ses_template" "work_archiver_template" {
  name    = "${var.stack_name}-template"
  subject = "Your download from {{referer}} is ready"
  html    = file("${path.module}/assets/email.html")
  text    = file("${path.module}/assets/email.txt")
}
