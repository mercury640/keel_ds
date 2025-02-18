output "application_subnets" {
  value = aws_subnet.application_subnets[*].id
}