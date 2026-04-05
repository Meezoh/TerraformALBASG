# ------------------------------------------------------------------------------
# THE ENTRY POINT: This is the URL you will paste into your browser
# ------------------------------------------------------------------------------
output "alb_dns_name" {
  description = "The public DNS name of the load balancer"
  value       = aws_lb.web_alb.dns_name
}

# ------------------------------------------------------------------------------
# FOR ANSIBLE: We need to know the ASG name to find the instances later
# ------------------------------------------------------------------------------
output "asg_name" {
  description = "The name of the Auto Scaling Group"
  value       = aws_autoscaling_group.web_asg.name
}

# ------------------------------------------------------------------------------
# LAUNCH TEMPLATE: Tracking the blueprint version
# ------------------------------------------------------------------------------
output "launch_template_id" {
  description = "The ID of the launch template being used"
  value       = aws_launch_template.web.id
}

output "latest_template_version" {
  description = "The most recent version of the launch template"
  value       = aws_launch_template.web.latest_version
}