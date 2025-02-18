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
  rds_master_user_name    = local.rds_master_cred["username"]
  rds_master_user_pass    = local.rds_master_cred["password"]
  rds_svc_user_name       = local.rds_service_user_cred["username"]
  rds_svc_user_pass       = local.rds_service_user_cred["password"]
  rds_address            = module.rds.db_instance_address
  ec2_instance_ids_map = {
    for idx, instance in module.ec2_adder :
    idx => instance.id
  }
}

# Get Availability Zones
data "aws_availability_zones" "available" {}

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

# Subnets for exposing service to internet by loadbalancers 
module "app_subnet" {
  source = "./modules/app_subnet"
  availability_zone = data.aws_availability_zones.available.names
  vpc_id = module.vpc.vpc_id
  app_public_subnet = var.app_public_subnet
  igw_id = module.vpc.igw_id
}

module "sg" {
  source = "./modules/sg"
  vpc_id = module.vpc.vpc_id
}

# Create log group
resource "aws_cloudwatch_log_group" "keel_ds" {
  name              = var.log_group
  retention_in_days = 7
}

# Get admin credential of database stored in secret manager
data "aws_secretsmanager_secret_version" "master_user" {
  secret_id = "rds_master_cred"
}
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
  username                = local.rds_master_user_name
  password                = local.rds_master_user_pass
  family                  = var.rds_parameter_group_family
  subnet_ids              = module.vpc.private_subnets
  vpc_security_group_ids  = [module.sg.private_sg]
  create_db_subnet_group  = true
  multi_az                = var.rds_multi_az
  publicly_accessible     = var.rds_publicly_accessible
  skip_final_snapshot     = var.rds_deletion_protection
  deletion_protection     = var.rds_skip_final_snapshot
  manage_master_user_password = false

  tags = {
    Name = "Keel PostgreSQL RDS"
  }

}

resource "aws_iam_policy" "cloudwatch_logs" {
  name = "cloudwatch-logs-policy"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow"
        Action   = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:ca-central-1:454451034868:log-group:${var.log_group}:*"
      }
    ]
  })
}

module "iam_ec2_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role"
  version = "~> 5.0"

  role_name         = "EC2CloudWatchLoggingRole"
  create_role       = true
  role_description  = "IAM role for EC2 Adder to write logs to CloudWatch"
  trusted_role_services = ["ec2.amazonaws.com"]

  custom_role_policy_arns = [
    "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    aws_iam_policy.cloudwatch_logs.arn
  ]
}

resource "aws_iam_instance_profile" "iam_ec2_adder_profile" {
  name = "ec2_adder_profile"
  role = module.iam_ec2_role.iam_role_name
}

data "aws_iam_role" "ecs_task_execution" {
  name = "ecsTaskExecutionRole"
}

resource "aws_iam_role_policy_attachment" "cloudwatch_logs" {
  role       = data.aws_iam_role.ecs_task_execution.name
  policy_arn = aws_iam_policy.cloudwatch_logs.arn
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
  subnet_id              = module.app_subnet.application_subnets[0]
  vpc_security_group_ids = [module.sg.application_sg]
  associate_public_ip_address = true
  key_name               = aws_key_pair.test_key.key_name
  user_data              = <<-EOF
                                #!/bin/bash
                                LOGFILE="/home/ec2-user/test.log"
                                exec > >(tee -a "$LOGFILE") 2>&1
                                set -x
                                echo "Script started at $(date)"
                                echo "Executing commands..."
                                curl -O https://s3.us-west-2.amazonaws.com/amazon-eks/1.31.3/2024-12-12/bin/linux/amd64/kubectl           
                                ARCH=amd64
                                PLATFORM=$(uname -s)_$ARCH
                                curl -sLO "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_$PLATFORM.tar.gz"
                                tar xvf eksctl_Linux_amd64.tar.gz
                                sudo chmod +x kubectl eksctl
                                sudo mv kubectl eksctl /usr/local/bin
                                sudo yum -y install postgresql15.x86_64
                                PGPASSWORD=${local.rds_master_user_pass} psql -h ${local.rds_address} -U master -d ${local.rds_svc_user_name} <<SQL
                                CREATE SCHEMA IF NOT EXISTS ${var.rds_schema_name};
                                CREATE TABLE IF NOT EXISTS ${var.rds_schema_name}.info (
                                    id SERIAL PRIMARY KEY,
                                    value INTEGER,
                                    ip TEXT
                                );
                                CREATE USER ${local.rds_svc_user_name} WITH PASSWORD '${local.rds_svc_user_pass}';
                                GRANT ALL PRIVILEGES ON DATABASE ${var.rds_db_name} TO ${local.rds_svc_user_name};
                                GRANT USAGE, CREATE ON SCHEMA ${var.rds_schema_name} TO ${local.rds_svc_user_name};
                                GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA ${var.rds_schema_name} TO ${local.rds_svc_user_name};
                                GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA ${var.rds_schema_name} TO ${local.rds_svc_user_name};
                                SQL
                                set +x
                                echo "Script finished at $(date)"
                                EOF
  depends_on = [module.rds]
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
  vpc_security_group_ids      = [module.sg.private_sg]
  key_name                    = aws_key_pair.test_key.key_name
  associate_public_ip_address = false
  user_data                   = <<-EOF
                                #!/bin/bash
                                LOGFILE="/home/ec2-user/testt.log"
                                exec > >(tee -a "$LOGFILE") 2>&1
                                set -x
                                echo "Script started at $(date)"
                                echo "Executing commands..."
                                sudo yum update -y
                                sudo yum install -y docker
                                sudo systemctl start docker
                                sudo systemctl enable docker
                                sudo yum install -y amazon-cloudwatch-agent
                                cat <<EOT | sudo tee /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
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
                                sudo amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json -s
                                sudo systemctl enable amazon-cloudwatch-agent

                                docker run -d --name adder -p 5001:5001 -e "DB_NAME=${var.rds_db_name}" -e "DB_USER=${local.rds_svc_user_name}" -e "DB_PASSWORD=${local.rds_svc_user_pass}" -e "DB_HOST=${local.rds_address}" -e "DB_PORT=${var.rds_db_port}"  ${var.ecr_adder}
                                set +x
                                echo "Script finished at $(date)"
                                EOF
}

module "ec2-alb" {
  source          = "./modules/alb"
  vpc_id          = module.vpc.vpc_id
  security_groups = [module.sg.application_sg]
  subnets         = module.app_subnet.application_subnets
  platform_type   = var.ec2_adder_name
  app_port        = var.app_adder_port
  target_type     = var.target_type_instance
  instance_ids    = local.ec2_instance_ids_map
}

module "ecs_display" {
  source                  = "./modules/ecs"
  vpc_id                  = module.vpc.vpc_id
  display_service_name    = var.display_service_name
  db_name                 = var.rds_db_name
  db_host                 = local.rds_address
  db_port                 = var.rds_db_port
  db_user_from            = var.db_svc_user_from_secret_manager_arn
  db_pass_from            = var.db_svc_pass_from_secret_manager_arn
  ecs_subnets             = module.vpc.private_subnets
  alb_subnets             = module.app_subnet.application_subnets
  ecs_security_group_ids  = [module.sg.private_sg]
  alb_security_group_ids  = [module.sg.application_sg]
  execution_role_arn      = data.aws_iam_role.ecs_task_execution.arn
  log_group               = var.log_group
}

module "eks_reset" {
  source = "./modules/eks"
  vpc_id = module.vpc.vpc_id
  cluster_name = var.reset_service_name
  cluster_subnets = module.vpc.private_subnets
  alb_security_groups = [module.sg.application_sg]
  alb_subnets = module.app_subnet.application_subnets
}