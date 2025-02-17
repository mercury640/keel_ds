resource "aws_subnet" "application_subnets" {
  count             = 3
  vpc_id           = var.vpc_id
  cidr_block       = element(var.app_public_subnet, count.index)
  availability_zone = element(var.availability_zone, count.index)
  map_public_ip_on_launch = true

  tags = {
    Name = "application-subnet-${count.index + 1}"
  }
}

# Route Table for Application Subnets
resource "aws_route_table" "application_rt" {
  vpc_id = var.vpc_id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = var.igw_id
  }

  tags = {
    Name = "ds-application-subnet"
  }
}

# Associate Application Subnets with Route Table
resource "aws_route_table_association" "application_subnet_association" {
  count          = 3
  subnet_id      = aws_subnet.application_subnets[count.index].id
  route_table_id = aws_route_table.application_rt.id
}