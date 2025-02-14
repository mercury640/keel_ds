variable "region" {}
variable "vpc_name" {}
variable "vpc_cidr_block" {}
variable "public_subnets" {}
variable "private_subnets" {}
variable "ec2_instance_type" {}
variable "app_ports" {}

variable "ecr_adder" {}
variable "ecr_display" {}
variable "ecr_reset" {}

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
variable "rds_schema_name" {}
variable "rds_table_name" {}