region              = "ca-central-1"
vpc_name            = "ds"
vpc_cidr_block      = "172.16.0.0/25"
public_subnets      = ["172.16.0.16/28", "172.16.0.32/28", "172.16.0.48/28"]
private_subnets     = ["172.16.0.64/28", "172.16.0.80/28", "172.16.0.96/28"]
ec2_instance_type   = "t2.micro"
app_ports           = [5001, 5002, 5003]