variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "elasticsearch_endpoint" {
  type = string
}

variable "email_access_policy_arn" {
  type = string
}

variable "elasticsearch_access_policy_arn" {
  type = string
}

variable "environment" {
  type = string
}

variable "index" {
  type = string
}

variable "name" {
  type    = string
  default = "work-archiver"
}

variable "sender_email" {
  type = string
}

variable "stack_name" {
  type    = string
  default = "work-archiver"
}

variable "tags" {
  type    = map(any)
  default = {}
}
