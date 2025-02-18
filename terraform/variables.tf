variable "region" {}
variable "vpc_name" {}
variable "vpc_cidr_block" {}
variable "public_subnets" {}
variable "private_subnets" {}
variable "app_public_subnet" {}

variable "log_group" {}
variable "adder_logfile_path" {}
variable "ec2_instance_type" {}
variable "ec2_adder_name" {}
variable "ec2_bastion_name" {}
variable "app_ports" {}
variable "app_adder_port" {}
variable "app_display_port" {}
variable "app_reset_port" {}
variable "ami_id" {}
variable "key_pair_name" {}
variable "pub_key_loc" {}
variable "adder_alb_name" {}
variable "display_alb_name" {}
variable "reset_alb_name" {}
variable "target_type_instance" {}
variable "target_type_ip" {}
variable "ec2_platform_name" {}
variable "fargate_platform_name" {}

variable "ecr_adder" {}
variable "ecr_display" {}
variable "ecr_reset" {}

variable "display_service_name" {}
variable "reset_service_name" {}

variable "rds_identifier" {}
variable "rds_engine" {}
variable "rds_engine_ver" {}
variable "rds_instance_class" {}
variable "rds_allocated_storage" {}
variable "rds_storage_encrypted" {}
variable "rds_parameter_group_family" {}
variable "rds_parameter_group_name_prefix" {}
variable "rds_multi_az" {}
variable "rds_replica_count" {}
variable "rds_publicly_accessible" {}
variable "rds_deletion_protection" {}
variable "rds_skip_final_snapshot" {}
variable "rds_db_name" {}
variable "rds_db_port" {}
variable "rds_schema_name" {}
variable "rds_table_name" {}

variable "db_svc_user_from_secret_manager_arn" {}
variable "db_svc_pass_from_secret_manager_arn" {}
