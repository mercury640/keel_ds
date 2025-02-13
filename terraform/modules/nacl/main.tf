resource "aws_network_acl" "public_nacl" {
  vpc_id = var.vpc_id

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
    rule_no    = 120
    action     = "allow"
    protocol   = "tcp"
    from_port  = 22
    to_port    = 22
    cidr_block = "0.0.0.0/0"
  }
  
  ingress {
    rule_no = 200
    action  = "deny"
    protocol = "-1"
    from_port  = 0
    to_port    = 0
    cidr_block = "0.0.0.0/0"
  }
}

# Network ACL for Private Subnets
resource "aws_network_acl" "private_nacl" {
  vpc_id = var.vpc_id

  dynamic ingress {
    for_each = var.public_subnets_cidr_blocks
    content {
      rule_no    = 130
      action     = "allow"
      protocol   = "tcp"
      from_port  = 5432
      to_port    = 5432
      cidr_block = ingress.value
    }
  }

  ingress {
    rule_no    = 200
    action     = "deny"
    protocol   = "-1"
    from_port  = 0
    to_port    = 0
    cidr_block = "0.0.0.0/0"
  }
}

resource "aws_network_acl_association" "public" {
  count          = length(var.public_subnets)
  subnet_id      = var.public_subnets[count.index]
  network_acl_id = aws_network_acl.public_nacl.id
}

resource "aws_network_acl_association" "private" {
  count          = length(var.private_subnets)
  subnet_id      = var.private_subnets[count.index]
  network_acl_id = aws_network_acl.private_nacl.id
}