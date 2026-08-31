terraform {
  required_version = ">= 1.9.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.27.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.0.0"
    }
  }

  provider_meta "aws" {
    user_agent = ["APN_1.1/pc_72gxmztpjz2hm5qnkkg0iiazo$"]
  }
}
