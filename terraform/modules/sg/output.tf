output "public_sg" {
  value = aws_security_group.public_sg.id
}

output "private_sg" {
  value = aws_security_group.private_sg.id
}