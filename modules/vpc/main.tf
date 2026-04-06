# ------------------------------------------------------------------------------
# VPC CORE: The main network container
# ------------------------------------------------------------------------------
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true

  tags = { Name = "dev-vpc" }
}

# ------------------------------------------------------------------------------
# PUBLIC NETWORKING: For the Application Load Balancer (ALB)
# ------------------------------------------------------------------------------
resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.azs[count.index]
  map_public_ip_on_launch = true

  tags = { Name = "dev-public-subnet-${count.index}" }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
}

resource "aws_route_table_association" "public" {
  count          = length(var.public_subnet_cidrs)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# ------------------------------------------------------------------------------
# NAT GATEWAY: Allows private instances to reach the internet for updates
# ------------------------------------------------------------------------------
resource "aws_eip" "nat" {  # Elastic IP is a Static Public IP for our NAT Gatewya
  domain = "vpc"
  tags   = { Name = "dev-nat-eip" }
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id # Sits in the public subnet
  tags          = { Name = "dev-nat-gateway" }

  depends_on = [aws_internet_gateway.gw]
}

# ------------------------------------------------------------------------------
# PRIVATE NETWORKING: For the 5 EC2 Instances (Secure Backend)
# ------------------------------------------------------------------------------
resource "aws_subnet" "private" {
  count                   = length(var.private_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.private_subnet_cidrs[count.index]
  availability_zone       = var.azs[count.index]
  map_public_ip_on_launch = false # No public accessibility

  tags = { Name = "dev-private-subnet-${count.index}" }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = { Name = "dev-private-rt" }
}

resource "aws_route_table_association" "private" { 
  count          = length(var.private_subnet_cidrs)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# ------------------------------------------------------------------------------
# ALB SECURITY GROUP: Allows the world to reach the Load Balancer
# ------------------------------------------------------------------------------
resource "aws_security_group" "alb_sg" {
  name        = "dev-alb-sg"
  description = "Allow HTTP inbound traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from Internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # The Public World
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ------------------------------------------------------------------------------
# DATA RESOURCE: This calls a public API to get your current public IP address
# ------------------------------------------------------------------------------
data "http" "my_ip" {
  url = "https://checkip.amazonaws.com"
}

# ------------------------------------------------------------------------------
# EC2 SECURITY GROUP: Only allows traffic from the ALB
# ------------------------------------------------------------------------------
resource "aws_security_group" "ec2_sg" {
  name        = "dev-ec2-fleet-sg"
  description = "Allow traffic from ALB only"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Traffic from ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id] # THIS IS THE CHAINING
  }

  # For Ansible/SSH (Temporary or via SSM)
  ingress {
    description = "SSH from a dynamic IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    # chomp() removes the hidden newline character from the API response
    cidr_blocks = ["${chomp(data.http.my_ip.response_body)}/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}