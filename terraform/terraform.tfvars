region                      = "ca-central-1"
vpc_name                    = "ds"
vpc_cidr_block              = "172.16.0.0/25"
public_subnets              = ["172.16.0.16/28", "172.16.0.32/28", "172.16.0.48/28"]
private_subnets             = ["172.16.0.64/28", "172.16.0.80/28", "172.16.0.96/28"]
ec2_instance_type           = "t2.micro"
app_ports                   = [5001, 5002, 5003]

ami_id                      = "ami-053a45fff0a704a47"
key_pair_name               = "test_key"
pub_key_loc                 = "~/.ssh/id_rsa.pub"
ec2_adder_name              = "adder_server"

ecr_adder                   = "public.ecr.aws/k3h4d7k6/ag/adder"
ecr_display                 = "public.ecr.aws/k3h4d7k6/ag/display"
ecr_reset                   = "public.ecr.aws/k3h4d7k6/ag/reset"

rds_identifier                  = "keel"
rds_db_name                     = "keel"
rds_schema_name                 = "keel"
rds_table_name                  = "info"
rds_engine                      = "postgres"
rds_engine_ver                  = "15"
rds_instance_class              = "db.t3.medium"
rds_allocated_storage           = 20
rds_storage_encrypted           = true
rds_parameter_group_family      = "postgres15"
rds_parameter_group_name_prefix = "postgres-db"
rds_multi_az                    = false
rds_replica_count               = 1
rds_publicly_accessible         = false
rds_deletion_protection         = false
rds_skip_final_snapshot         = true