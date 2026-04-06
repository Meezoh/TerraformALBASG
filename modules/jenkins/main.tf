# ==============================================================================
# SECTION -1: AUTO-IP DETECTION (The "No More Manual Changes" Fix)
# ==============================================================================
data "http" "my_public_ip" {
  url = "http://ifconfig.me/ip"
}

# ==============================================================================
# SECTION 0: IDENTITY & ACCESS (IAM for SSM)
# ==============================================================================
resource "aws_iam_role" "jenkins_role" {
  name = "jenkins-master-ssm-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_attach" {
  role       = aws_iam_role.jenkins_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "jenkins_profile" {
  name = "jenkins-instance-profile"
  role = aws_iam_role.jenkins_role.name
}

# ==============================================================================
# SECTION 1: NETWORK SECURITY (The Secure Door)
# ==============================================================================
resource "aws_security_group" "jenkins_sg" {
  name        = "jenkins-access-sg"
  description = "Restricted access to Jenkins UI"
  vpc_id      = var.vpc_id

  ingress {
    description = "Jenkins Dashboard Access"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [var.my_detected_ip]                              # Your Control Server
  }

  ingress {
    description = "SSH Management"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_detected_ip]                              # Your Control Server
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "dev-jenkins-sg" }
}

# ==============================================================================
# SECTION 2: COMPUTE RESOURCE (Dockerized Jenkins)
# ==============================================================================
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

resource "aws_instance" "jenkins_server" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  
  subnet_id                   = var.public_subnet_id
  vpc_security_group_ids      = [aws_security_group.jenkins_sg.id]
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.jenkins_profile.name
  
  user_data = <<-EOF
            #!/bin/bash
            # 1. Logging setup
            exec > >(tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1
            
            # 2. Install Docker
            apt-get update -y
            apt-get install -y docker.io
            systemctl enable --now docker
            sudo usermod -aG docker ubuntu

            # 3. Launch Jenkins with Persistence
            # We map 8080:8080 and create a volume named 'jenkins_data'
            docker run -d \
              --name jenkins \
              --restart unless-stopped \
              -p 8080:8080 \
              -p 50000:50000 \
              -v jenkins_data:/var/jenkins_home \
              jenkins/jenkins:lts

            # 4. Wait for Jenkins to wake up and print the password
            echo "Waiting for Jenkins to generate the admin password..."
            sleep 30
            docker logs jenkins 2>&1 | grep -A 5 "Please use the following password"
            EOF

  tags = {
    Name = "dev-jenkins-server"
    Role = "jenkins-master"
  }
}