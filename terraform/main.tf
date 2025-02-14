terraform {
  backend "s3" {
    bucket  = "terraform-remote-demo"
    key     = "demo/state.tfstate"
    region  = "ca-central-1"
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

  manage_default_network_acl = false
  manage_default_route_table = false
  manage_default_security_group = false
}

module "nacl" {
  source = "./modules/nacl"
  vpc_id = module.vpc.vpc_id
  public_subnets = module.vpc.public_subnets
  private_subnets = module.vpc.private_subnets
  public_subnets_cidr_blocks = module.vpc.public_subnets_cidr_blocks
}

module "sg" {
  source = "./modules/sg"
  vpc_id = module.vpc.vpc_id
}

# Fetch master password from AWS Secrets Manager
data "aws_secretsmanager_secret_version" "master_user" {
  secret_id = "rds_master_cred"
}

# Fetch service user password from AWS Secrets Manager
data "aws_secretsmanager_secret_version" "service_user" {
  secret_id = "keel_rds_cred"
}

locals {
  rds_master_cred         = jsondecode(data.aws_secretsmanager_secret_version.master_user.secret_string)
  rds_service_user_cred   = jsondecode(data.aws_secretsmanager_secret_version.service_user.secret_string)
}

output "subnet_ids" {
  value = module.vpc.private_subnets
}

output "vpc_security_group_ids" {
  value = module.sg.pri_sg
}

module "rds" {
  source  = "terraform-aws-modules/rds/aws"
  version = "6.10.0" 
  identifier              = var.rds_identifier
  engine                  = var.rds_engine
  engine_version          = var.rds_engine_ver
  db_name                 = var.rds_db_name
  instance_class          = var.rds_instance_class
  allocated_storage       = var.rds_allocated_storage
  storage_encrypted       = var.rds_storage_encrypted
  username                = local.rds_master_cred["username"]
  password                = local.rds_master_cred["password"]
  family                  = var.rds_parameter_group_family
  subnet_ids              = module.vpc.private_subnets
  vpc_security_group_ids  = [module.sg.pri_sg]
  create_db_subnet_group  = true
  multi_az                = var.rds_multi_az
  publicly_accessible     = var.rds_publicly_accessible
  skip_final_snapshot     = var.rds_deletion_protection
  deletion_protection     = var.rds_skip_final_snapshot

  tags = {
    Name = "Keel PostgreSQL RDS"
  }

}

module "ec2_instance_1" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "~> 5.0"

  name           = "instance-1"
  ami            = "ami-xxxxxxxxxxxxxxxxx"  # Amazon Linux AMI ID
  instance_type  = "t2.micro"
  subnet_id      = aws_subnet.subnet1.id
  security_groups = [aws_security_group.instance1_sg.id]
  key_name       = aws_key_pair.instance2_key.key_name

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y docker
              systemctl start docker
              systemctl enable docker
              docker run -d --name adder -p 5001:5001 \
              -e "DB_NAME=keel" -e "DB_USER=mercury" -e "DB_PASSWORD=0" \
              -e "DB_HOST=192.168.2.109" -e "DB_PORT=5432" adder
              EOF
}

module "init_rds" {
  source = "./modules/init_rds"
  rds_db_name     = var.rds_db_name
  rds_endpoint    = module.rds.db_instance_endpoint
  rds_master_user = local.rds_master_cred["username"]
  rds_master_pass = local.rds_master_cred["password"]
  rds_serv_user   = local.rds_service_user_cred["username"]
  rds_serv_pass   = local.rds_service_user_cred["password"]
  rds_table_name  = var.rds_table_name
  rds_schema_name = var.rds_schema_name
}