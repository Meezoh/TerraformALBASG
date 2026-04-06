# ==============================================================================
# DATABASE TIER: The Single Source of Truth
# ==============================================================================

# 1. Create a dedicated Security Group for the Database
resource "aws_security_group" "db_sg" {
  name        = "dev-db-sg"
  description = "Allow Postgres traffic from Web Servers only"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    # This is the "Magic" - ONLY allow instances with the Web SG to enter
    security_groups = [var.ec2_sg_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "dev-db-sg" }
}

# 2. Launch the Single Database Instance
resource "aws_instance" "db_server" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
  
  # Put it in the first private subnet
  subnet_id              = var.private_subnet_ids[0]
  vpc_security_group_ids = [aws_security_group.db_sg.id]

  user_data = <<-EOF
    #!/bin/bash
    # 1. Set Local Fact as Database
    mkdir -p /etc/ansible/facts.d
    echo '{"Role": "database"}' > /etc/ansible/facts.d/tags.fact

    # 2. Install and Pull
    apt-get update
    apt-get install -y ansible git
    ansible-pull -U https://github.com/Meezoh/Ansible.git -d /tmp/ansible setup.yaml
  EOF
  
  # Give it the same SSM badge so we can log into it too!
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name

  tags = {
    Name = "dev-db-server"
    Role = "database"
  }
}

# ==============================================================================
# IAM IDENTITY: Security Badge for EC2 to use AWS Systems Manager (SSM)
# ==============================================================================

# 1. Create the Role (The "Job Title")
resource "aws_iam_role" "ec2_role" {
  name = "dev-web-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

# 2. Attach the SSM Policy (The "Permissions")
resource "aws_iam_role_policy_attachment" "ssm_attach" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# 3. Create the Instance Profile (The actual "ID Badge" the EC2 wears)
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "dev-web-ssm-profile"
  role = aws_iam_role.ec2_role.name
}

# ------------------------------------------------------------------------------
# LAUNCH TEMPLATE: The "Blueprint" for your 5 EC2 instances
# ------------------------------------------------------------------------------
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical (Ubuntu)

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

resource "aws_launch_template" "web" {
  name_prefix   = "dev-web-template"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"

  tags = {
    # This reaches "up and out" of the module to find the ansible folder
    # It will only trigger a refresh if the YAML actually changes.
    "ConfigHash" = filebase64sha256("${path.module}/../../ansible/setup.yaml")
  }

  vpc_security_group_ids = [var.ec2_sg_id]

  # THE BOOTSTRAP: Configuring 5 Workers to find the 1 DB
  user_data = base64encode(<<-EOF
    #!/bin/bash
    # 1. Inject Database Connection Info
    echo "DB_HOST=${aws_instance.db_server.private_ip}" >> /etc/environment
    echo "DB_NAME=devops_db" >> /etc/environment

    # 2. Set Local Fact (Identity) for Ansible
    mkdir -p /etc/ansible/facts.d
    echo '{"Role": "web-worker"}' > /etc/ansible/facts.d/tags.fact

    # 3. Install Ansible and Git
    apt-get update
    apt-get install -y ansible git

    # 4. Pull and Run the Master Playbook from GitHub
    ansible-pull -U https://github.com/Meezoh/Ansible.git -d /tmp/ansible setup.yaml
  EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "dev-web-server"
      Role = "web-worker"
    }
  }

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_profile.name
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
  target_group_arns   = [aws_lb_target_group.web_tg.arn] # AWS automatically registers our 4/5/7 instances into the ALBs target group
  health_check_type   = "ELB"

  min_size         = 4
  max_size         = 7
  desired_capacity = 5

  launch_template {
    id      = aws_launch_template.web.id
    version = "$Latest"
  }

  # THE SENIOR REFRESH: This handles the rolling replacement
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50 # Keep half the fleet alive while swapping
    }
  }

  depends_on = [aws_lb_listener.http]
}