data "aws_availability_zones" "available" {}

data "aws_ecrpublic_authorization_token" "token" {
  region = "us-east-1"
}