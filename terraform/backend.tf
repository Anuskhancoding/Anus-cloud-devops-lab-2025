terraform {
  backend "s3" {
    bucket         = "terraform-state-devops-lab"
    key            = "devops-lab/terraform.tfstate"
    region         = "eu-north-1"
    dynamodb_table = "terraform-lock"
  }
}
