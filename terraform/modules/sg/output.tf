output "public_sg" {
  value = aws_security_group.public_sg.id
}

output "public_bastion" {
  value = aws_security_group.public_bastion.id
}

output "private_sg" {
  value = aws_security_group.private_sg.id
}