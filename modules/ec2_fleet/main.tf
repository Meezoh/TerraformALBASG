# ------------------------------------------------------------------------------
# LAUNCH TEMPLATE: The "Blueprint" for your 5 EC2 instances
# ------------------------------------------------------------------------------
resource "aws_launch_template" "web" {
  name_prefix   = "dev-web-template"
  image_id      = "ami-0e2c8ccd4e1ff87e6" # Ubuntu 24.04 in us-east-1
  instance_type = "t2.nano"

  vpc_security_group_ids = [var.ec2_sg_id]

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "dev-web-server"
      Role = "web-server"
    }
  }

  iam_instance_profile {
    name = "AmazonSSMManagedInstanceCore" 
  }
}

# ------------------------------------------------------------------------------
# APPLICATION LOAD BALANCER: The public entry point
# ------------------------------------------------------------------------------
resource "aws_lb" "web_alb" {
  name               = "dev-web-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_sg_id]
  subnets            = var.public_subnet_ids

  tags = { Name = "dev-web-alb" }
}

# ------------------------------------------------------------------------------
# TARGET GROUP: The "Waiting Room" for your 5 servers
# ------------------------------------------------------------------------------
resource "aws_lb_target_group" "web_tg" {
  name     = "dev-web-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    path                = "/"
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

# ------------------------------------------------------------------------------
# LISTENER: Listens on Port 80 and forwards to the Target Group
# ------------------------------------------------------------------------------
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.web_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_tg.arn
  }
}

# ------------------------------------------------------------------------------
# AUTO SCALING GROUP: The "Manager" for your 5 private instances
# ------------------------------------------------------------------------------
resource "aws_autoscaling_group" "web_asg" {
  name                = "dev-web-asg"
  vpc_zone_identifier = var.private_subnet_ids
  target_group_arns   = [aws_lb_target_group.web_tg.arn]
  health_check_type   = "ELB"

  min_size         = 5
  max_size         = 5
  desired_capacity = 5

  launch_template {
    id      = aws_launch_template.web.id
    version = "$Latest"
  }

  depends_on = [aws_lb_listener.http]
}