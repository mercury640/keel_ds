terraform {
  backend "s3" {
    bucket  = "terraform-remote-demo"
    key     = "demo/state.tfstate"
    region  = "ca-central-1"
  }
}

locals {
  rds_master_cred         = jsondecode(data.aws_secretsmanager_secret_version.master_user.secret_string)
  rds_service_user_cred   = jsondecode(data.aws_secretsmanager_secret_version.service_user.secret_string)
  rds_endpoint            = module.rds.db_instance_endpoint
  ec2_instance_ids_map = {
    for idx, instance in module.ec2_adder :
    idx => instance.id
  }
}

# Get Availability Zones
data "aws_availability_zones" "available" {}

# Create VPC
module "vpc" {
  source                          = "terraform-aws-modules/vpc/aws"
  version                         = "5.19.0"
  name                            = var.vpc_name
  cidr                            = var.vpc_cidr_block
  azs                             = data.aws_availability_zones.available.names
  public_subnets                  = var.public_subnets
  private_subnets                 = var.private_subnets
  enable_nat_gateway              = true
  single_nat_gateway              = true
  enable_dns_hostnames            = true
  enable_dns_support              = true
  manage_default_network_acl      = false
  manage_default_route_table      = false
  manage_default_security_group   = false
}

module "nacl" {
  source                        = "./modules/nacl"
  vpc_id                        = module.vpc.vpc_id
  public_subnets                = module.vpc.public_subnets
  private_subnets               = module.vpc.private_subnets
  public_subnets_cidr_blocks    = module.vpc.public_subnets_cidr_blocks
}

module "sg" {
  source = "./modules/sg"
  vpc_id = module.vpc.vpc_id
}

module "log_group" {
  source  = "terraform-aws-modules/cloudwatch/aws//modules/log-group"
  version = "~> 3.0"

  name              = var.log_group
  retention_in_days = 7
}

# Fetch master password from AWS Secrets Manager
data "aws_secretsmanager_secret_version" "master_user" {
  secret_id = "rds_master_cred"
}

# Fetch service user password from AWS Secrets Manager
data "aws_secretsmanager_secret_version" "service_user" {
  secret_id = "keel_rds_cred"
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
  vpc_security_group_ids  = [module.sg.private_sg]
  create_db_subnet_group  = true
  multi_az                = var.rds_multi_az
  publicly_accessible     = var.rds_publicly_accessible
  skip_final_snapshot     = var.rds_deletion_protection
  deletion_protection     = var.rds_skip_final_snapshot

  tags = {
    Name = "Keel PostgreSQL RDS"
  }

}

module "iam_log_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role"
  version = "~> 5.0"

  role_name         = "EC2CloudWatchLoggingRole"
  create_role       = true
  role_description  = "IAM role for EC2 Adder to write logs to CloudWatch"
  trusted_role_services = ["ec2.amazonaws.com"]

  custom_role_policy_arns = [
    "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  ]
}

resource "aws_iam_instance_profile" "iam_ec2_adder_profile" {
  name = "ec2_adder_profile"
  role = module.iam_log_role.iam_role_name
}

resource "aws_key_pair" "test_key" {
  key_name   = var.key_pair_name
  public_key = file(var.pub_key_loc)
}

module "ec2_bastion" {
  source                 = "terraform-aws-modules/ec2-instance/aws"
  version                = "5.7.1"

  name                   = var.ec2_bastion_name
  ami                    = var.ami_id
  instance_type          = var.ec2_instance_type
  subnet_id              = module.vpc.private_subnets[0]
  vpc_security_group_ids = [module.sg.public_bastion]
  key_name               = aws_key_pair.test_key.key_name
  user_data              = <<-EOF
                                #!/bin/bash
                                curl -O https://s3.us-west-2.amazonaws.com/amazon-eks/1.31.3/2024-12-12/bin/linux/amd64/kubectl           
                                ARCH=amd64
                                PLATFORM=$(uname -s)_$ARCH
                                curl -sLO "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_$PLATFORM.tar.gz"
                                tar xvf eksctl_Linux_amd64.tar.gz
                                sudo chmod +x kubectl eksctl
                                sudo mv kubectl eksctl /usr/local/bin

                                sudo yum -y install postgresql15.x86_64
                                PGPASSWORD=${local.rds_master_cred["password"]} psql -h ${local.rds_endpoint} -U master -d ${local.rds_master_cred["username"]} <<SQL
                                CREATE SCHEMA IF NOT EXISTS ${var.rds_schema_name};
                                CREATE TABLE IF NOT EXISTS ${var.rds_schema_name}.info (
                                    id SERIAL PRIMARY KEY,
                                    value INTEGER,
                                    ip TEXT
                                );
                                CREATE USER ${local.rds_service_user_cred["username"]} WITH PASSWORD ${local.rds_service_user_cred["password"]};
                                GRANT ALL PRIVILEGES ON DATABASE ${var.rds_db_name} TO ${local.rds_service_user_cred["username"]};
                                GRANT USAGE, CREATE ON SCHEMA ${var.rds_schema_name} TO ${local.rds_service_user_cred["username"]};
                                GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA ${var.rds_schema_name} TO ${local.rds_service_user_cred["username"]};
                                SQL
                                EOF
}

module "ec2_adder" {
  source                      = "terraform-aws-modules/ec2-instance/aws"
  version                     = "5.7.1"
  count                       = 2

  name                        = "${var.ec2_adder_name}-${count.index + 1}"
  ami                         = var.ami_id
  instance_type               = var.ec2_instance_type
  iam_instance_profile        = aws_iam_instance_profile.iam_ec2_adder_profile.name
  subnet_id                   = module.vpc.private_subnets[count.index]
  vpc_security_group_ids      = [module.sg.public_sg]
  key_name                    = aws_key_pair.test_key.key_name
  associate_public_ip_address = false
  user_data                   =  <<-EOF
                                #!/bin/bash
                                sudo yum update -y
                                sudo yum install -y docker
                                sudo systemctl start docker
                                sudo systemctl enable docker
                                sudo yum install -y amazon-cloudwatch-agent
                                cat <<EOT | sudo tee /opt/aws/amazon-cloudwatch-agent/etc/cloudwatch-config.json
                                    {
                                        "logs": {
                                            "logs_collected": {
                                                "files": {
                                                    "collect_list": [
                                                        {
                                                            "file_path": "${var.adder_logfile_path}",
                                                            "log_group_name": "${var.log_group}",
                                                            "log_stream_name": "${var.ec2_adder_name}-${count.index + 1}",
                                                            "timezone": "UTC"
                                                        }
                                                    ]
                                                }
                                            }
                                        }
                                    }
                                    EOT
                                sudo amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c file:/opt/aws/amazon-cloudwatch-agent/etc/cloudwatch-config.json -s
                                sudo systemctl enable amazon-cloudwatch-agent

                                docker run -d --name adder -p 5001:5001 -e "DB_NAME=${var.rds_db_name}" -e "DB_USER=${local.rds_service_user_cred["username"]}" -e "DB_PASSWORD=${local.rds_service_user_cred["password"]}" -e "DB_HOST=${local.rds_endpoint}" -e "DB_PORT=${var.rds_db_port}"  adder
                                EOF
}

module "ec2-alb" {
  source = "./modules/alb"
  vpc_id = module.vpc.vpc_id
  security_groups = [module.sg.public_sg]
  subnets = module.vpc.public_subnets
  platform_type = var.ec2_platform_name
  app_port = var.app_adder_port
  target_type = var.target_type_instance
  instance_ids = local.ec2_instance_ids_map
}