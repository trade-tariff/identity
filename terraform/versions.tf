terraform {
  required_version = ">=1.12"

  required_providers {
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5"
    }
  }

  backend "s3" {}
}

provider "aws" {}
