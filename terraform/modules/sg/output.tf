output "pub_sg" {
  value = aws_security_group.public_sg.id
}

output "pub_bastion_sg" {
  value = aws_security_group.public_bastion.id
}

output "pri_sg" {
  value = aws_security_group.private_sg.id
}