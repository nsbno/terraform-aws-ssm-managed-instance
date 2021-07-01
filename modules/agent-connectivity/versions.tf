terraform {
  required_version = ">= 0.12.26"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 2.46.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = ">= 1.3.0"
    }
  }
}
