terraform {
  backend "s3" {
    key    = "work-archiver.tfstate"
    region = "us-east-1"
  }

  required_providers {
    aws = {
      version   = "~> 4.0"
      source    = "hashicorp/aws"
    }
  }
}


provider "aws" {
  region = var.aws_region

  default_tags {
    tags = var.tags
  }
}

data "aws_caller_identity" "current" {}
