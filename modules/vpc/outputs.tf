output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id # The '*' sends all IDs as a list
}

output "private_subnet_ids" {
  value = aws_subnet.private[*].id # The '*' sends all IDs as a list
}

output "alb_sg_id" {
  value = aws_security_group.alb_sg.id
}

output "ec2_sg_id" {
  value = aws_security_group.ec2_sg.id
}

#The chomp function just cleans up any hidden "new line" characters from the web response
output "my_detected_ip" {
  description = "The public IP of the machine running Terraform"
  value       = "${chomp(data.http.my_ip.response_body)}/32" 
}