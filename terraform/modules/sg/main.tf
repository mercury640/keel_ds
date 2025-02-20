resource "aws_security_group" "public_sg" {
  name        = "public-sg"
  description = "Allow HTTP, HTTPS, and SSH"
  vpc_id      = var.vpc_id

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
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Security Group for Private Subnets
resource "aws_security_group" "private_sg" {
  name        = "private-sg"
  description = "Allow PostgreSQL from public SG"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    self            = true
    security_groups = [aws_security_group.public_sg.id]
  }
  ingress {
    from_port   = 5001
    to_port     = 5003
    protocol    = "tcp"
    self        = true
    security_groups = [aws_security_group.public_sg.id]
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    self        = true
    security_groups = [aws_security_group.public_sg.id]
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    self        = true
    security_groups = [aws_security_group.public_sg.id]
  }
  ingress {
    from_port   = 10250
    to_port     = 10250
    protocol    = "tcp"
    self        = true
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}