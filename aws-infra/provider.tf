// https://registry.terraform.io/providers/hashicorp/aws/latest/docs
// https://letslearndevops.com/2017/07/24/how-to-secure-terraform-credentials/

terraform {
  required_version = ">= 0.14.0"
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "5.97.0" # updated for May 2025
    }
  }
}

provider "aws" {
  
  //access_key = var.aws_access_key
  //secret_key = var.aws_secret_key

  // instead of aws access and secret keys, use file format that comes from 'aws configure'
  shared_credentials_files = ["~/.aws/credentials"]
  #profile = "default"

  region = var.aws_region
}



