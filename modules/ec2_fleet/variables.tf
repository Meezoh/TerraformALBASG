variable "vpc_id" {
  type        = string
  description = "The ID of the VPC where the fleet will live"
}

variable "public_subnet_ids" {
  type        = list(string)
  description = "Subnets for the Load Balancer"
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Subnets for the EC2 instances"
}

variable "alb_sg_id" {
  type        = string
  description = "Security Group for the ALB"
}

variable "ec2_sg_id" {
  type        = string
  description = "Security Group for the EC2 instances"
}

variable "project_root" {
  type        = string
  description = "The absolute path to the root of the repo"
}