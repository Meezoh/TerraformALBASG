# ==============================================================================
# SECTION 1: JENKINS CONNECTION INFO
# ==============================================================================

output "jenkins_public_ip" {
  description = "The public IP of our new Jenkins Master"
  value       = aws_instance.jenkins_server.public_ip
}

output "jenkins_url" {
  description = "Click this to open the dashboard"
  value       = "http://${aws_instance.jenkins_server.public_ip}:8080"
}