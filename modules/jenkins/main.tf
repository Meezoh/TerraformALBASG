# ==============================================================================
# SECTION -1: AUTO-IP DETECTION (The "No More Manual Changes" Fix)
# ==============================================================================
data "http" "my_public_ip" {
  url = "http://ifconfig.me/ip"
}

# ==============================================================================
# SECTION 0: IDENTITY & ACCESS (IAM for Jenkins + Terraform/Terragrunt)
# ==============================================================================
resource "aws_iam_role" "jenkins_role" {
  name = "jenkins-master-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# SSM access so you can connect with Session Manager
resource "aws_iam_role_policy_attachment" "ssm_attach" {
  role       = aws_iam_role.jenkins_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Broad access so Jenkins can run Terragrunt/Terraform against AWS
# Good for lab/project. Tighten later for production.
resource "aws_iam_role_policy_attachment" "admin_attach" {
  role       = aws_iam_role.jenkins_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
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
    cidr_blocks = [var.my_detected_ip]
  }

  ingress {
    description = "SSH Management"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_detected_ip]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "dev-jenkins-sg"
  }
}

# ==============================================================================
# SECTION 2: COMPUTE RESOURCE (Dockerized Jenkins with Terraform Tooling)
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
    exec > >(tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1

    echo "========== STARTING JENKINS BOOTSTRAP =========="

    # ------------------------------------------------------------------------------
    # 1. Base packages
    # ------------------------------------------------------------------------------
    apt-get update -y
    apt-get install -y \
      docker.io \
      curl \
      unzip \
      git \
      ca-certificates \
      gnupg \
      lsb-release \
      apt-transport-https \
      software-properties-common

    systemctl enable --now docker
    usermod -aG docker ubuntu

    # ------------------------------------------------------------------------------
    # 2. Install AWS CLI v2 on the host
    # ------------------------------------------------------------------------------
    cd /tmp
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip -o awscliv2.zip
    ./aws/install
    aws --version

    # ------------------------------------------------------------------------------
    # 3. Install Terraform on the host
    # ------------------------------------------------------------------------------
    cd /tmp
    curl -fsSL https://releases.hashicorp.com/terraform/1.8.5/terraform_1.8.5_linux_amd64.zip -o terraform.zip
    unzip -o terraform.zip
    mv terraform /usr/local/bin/terraform
    chmod +x /usr/local/bin/terraform
    terraform -version

    # ------------------------------------------------------------------------------
    # 4. Install Terragrunt on the host
    # ------------------------------------------------------------------------------
    curl -L https://github.com/gruntwork-io/terragrunt/releases/download/v0.67.16/terragrunt_linux_amd64 -o /usr/local/bin/terragrunt
    chmod +x /usr/local/bin/terragrunt
    terragrunt -version

    # ------------------------------------------------------------------------------
    # 5. Create a custom Jenkins Docker image with all tooling inside the container
    # ------------------------------------------------------------------------------
    mkdir -p /opt/jenkins-custom
    cd /opt/jenkins-custom

    cat > Dockerfile <<'DOCKERFILE'
    FROM jenkins/jenkins:lts

    USER root

    RUN apt-get update && apt-get install -y \
        curl \
        unzip \
        git \
        ca-certificates \
        gnupg \
        lsb-release \
        python3 \
        python3-pip \
        && rm -rf /var/lib/apt/lists/*

    # Install AWS CLI v2
    RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip" && \
        unzip /tmp/awscliv2.zip -d /tmp && \
        /tmp/aws/install && \
        rm -rf /tmp/aws /tmp/awscliv2.zip

    # Install Terraform
    RUN curl -fsSL https://releases.hashicorp.com/terraform/1.8.5/terraform_1.8.5_linux_amd64.zip -o /tmp/terraform.zip && \
        unzip /tmp/terraform.zip -d /usr/local/bin && \
        rm -f /tmp/terraform.zip

    # Install Terragrunt
    RUN curl -L https://github.com/gruntwork-io/terragrunt/releases/download/v0.67.16/terragrunt_linux_amd64 -o /usr/local/bin/terragrunt && \
        chmod +x /usr/local/bin/terragrunt

    # Verify installs during build
    RUN terraform -version && \
        terragrunt -version && \
        aws --version && \
        git --version

    USER jenkins
    DOCKERFILE

    docker build -t custom-jenkins-iac .

    # ------------------------------------------------------------------------------
    # 6. Run Jenkins container
    # ------------------------------------------------------------------------------
    docker rm -f jenkins || true

    docker run -d \
      --name jenkins \
      --restart unless-stopped \
      -p 8080:8080 \
      -p 50000:50000 \
      -v jenkins_data:/var/jenkins_home \
      custom-jenkins-iac

    # ------------------------------------------------------------------------------
    # 7. Wait for Jenkins and print initial admin password
    # ------------------------------------------------------------------------------
    echo "Waiting for Jenkins to start..."
    sleep 45

    echo "========== JENKINS INITIAL PASSWORD =========="
    docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword || true

    echo "========== TOOL VERSIONS INSIDE CONTAINER =========="
    docker exec jenkins terraform -version || true
    docker exec jenkins terragrunt -version || true
    docker exec jenkins aws --version || true
    docker exec jenkins git --version || true

    echo "========== BOOTSTRAP COMPLETE =========="
  EOF

  tags = {
    Name = "dev-jenkins-server"
    Role = "jenkins-master"
  }
}