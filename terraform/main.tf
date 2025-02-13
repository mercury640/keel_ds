terraform {
  backend "s3" {
    bucket = "terraform-remote-demo"
    key = "demo/state.tfstate"
    region = "ca-central-1"
  }
}

# Get Availability Zones
data "aws_availability_zones" "available" {}

# Create VPC
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.19.0"

  name = var.vpc_name
  cidr = var.vpc_cidr_block

  azs             = data.aws_availability_zones.available.names
  public_subnets  = var.public_subnets
  private_subnets = var.private_subnets

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true
  enable_dns_support   = true
}

