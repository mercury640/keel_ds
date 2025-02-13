resource "aws_network_acl" "public_nacl" {
  vpc_id = module.vpc.vpc_id

  ingress {
    rule_no    = 100
    action     = "allow"
    protocol   = "tcp"
    from_port  = 80
    to_port    = 80
    cidr_block = "0.0.0.0/0"
  }
  
  ingress {
    rule_no    = 110
    action     = "allow"
    protocol   = "tcp"
    from_port  = 443
    to_port    = 443
    cidr_block = "0.0.0.0/0"
  }
  
  ingress {
    rule_no = 200
    action  = "deny"
    protocol = "-1"
    cidr_block = "0.0.0.0/0"
  }
}

# Network ACL for Private Subnets
resource "aws_network_acl" "private_nacl" {
  vpc_id = module.vpc.vpc_id

  ingress {
    rule_no    = 100
    action     = "deny"
    protocol   = "-1"
    cidr_block = "0.0.0.0/0"
  }
}