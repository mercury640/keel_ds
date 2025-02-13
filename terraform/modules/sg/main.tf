# Security Group for Public Subnets
resource "aws_security_group" "public_sg" {
  name        = "public-sg"
  description = "Allow HTTP, HTTPS, and internal communication"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  dynamic "ingress" {
    for_each = var.app_ports
    content {
      from_port       = ingress.value
      to_port         = ingress.value
      protocol        = "tcp"
      security_groups = [aws_security_group.public_sg.id]
    }
  }
}

# Security Group for Private Subnets
resource "aws_security_group" "private_sg" {
  name        = "private-sg"
  description = "Allow PostgreSQL from public SG"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.public_sg.id]
  }
}