terraform {
  backend "s3" {
    bucket  = "pichincha-backoffice-tfstate"
    region  = "us-east-1"
    key     = "apim/terraform.tfstate"
    encrypt = true
  }
}
