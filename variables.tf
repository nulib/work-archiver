
variable "aws_region" {
  type    = string
  default = "us-east-1"
}
variable "stack_name" {
  type    = string
  default = "work-archiver"
}

variable "environment" {
  type = string
}

variable "tags" {
  type    = map(any)
  default = {}
}
