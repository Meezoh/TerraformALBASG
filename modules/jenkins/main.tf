# ==============================================================================
# SECTION 1: NETWORK SECURITY (Firewall Rules)
# ==============================================================================
resource "aws_security_group" "jenkins_sg" {
  name        = "jenkins-access-sg"
  description = "Restricted access to Jenkins UI and SSH"
  vpc_id      = var.vpc_id

  # Rule: Allow Jenkins Web UI (Restrict to your IP only)
  ingress {
    description = "Jenkins Dashboard Access"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [var.my_detected_ip] 
  }

  # Rule: Allow SSH Management (Restrict to your IP only)
  ingress {
    description = "SSH Management Access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_detected_ip]
  }

  # Rule: Allow ALL Outbound (Required for plugin/binary downloads)
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "dev-jenkins-sg" }
}

# ==============================================================================
# SECTION 2: COMPUTE RESOURCE (The Jenkins Master)
# ==============================================================================
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical (Ubuntu)

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

resource "aws_instance" "jenkins_server" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  
  # Network Configuration
  subnet_id                   = var.public_subnet_id
  vpc_security_group_ids      = [aws_security_group.jenkins_sg.id]
  associate_public_ip_address = true 
  
  # ----------------------------------------------------------------------------
  # BOOTSTRAP: Automated Software Installation (User Data)
  # ----------------------------------------------------------------------------
  user_data = <<-EOF
              #!/bin/bash
              apt-get update -y
              apt-get install -y openjdk-17-jre
              
              # Add Jenkins Repository and Key
              curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | sudo tee /usr/share/keyrings/jenkins-keyring.asc > /dev/null
              echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/ | sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null
              
              # Install and Start Jenkins
              apt-get update -y
              apt-get install -y jenkins
              systemctl enable jenkins
              systemctl start jenkins
              EOF

  tags = {
    Name = "dev-jenkins-server"
    Role = "jenkins-master"
  }
}