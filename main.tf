terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.27"
    }
  }
  required_version = ">= 1.0.7"
}

provider "aws" {
  profile = "mfa"
  region  = "eu-west-1"
}

provider "aws" {
  alias   = "Frankfurt" 
  profile = "mfa"
  region  = "eu-central-1"
}
module "ec2" {
  source = "./modules"
  name   = "HelloWorld"
}

module "ec2_Frankfurt" {
  source = "./modules"
  name   = "HelloWorld_in_Frankfurt"
  providers = {
    aws = aws.Frankfurt
  }
}