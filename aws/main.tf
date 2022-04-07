terraform {
  backend "s3" {
    key    = "work-archiver.tfstate"
    region = "us-east-1"
  }
}


provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}
