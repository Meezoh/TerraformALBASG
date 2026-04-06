variable "vpc_cidr" {
  type        = string
  description = "The CIDR block for the VPC"
  # No default needed here because Terragrunt supplies it!
}

# For the ALB
variable "public_subnet_cidrs" {
  type        = list(string)
  description = "List of public subnet CIDRs"
}

# For the 5 EC2s
variable "private_subnet_cidrs" {
  type        = list(string)
  description = "List of private subnet CIDRs"
}

# Two different AZs
variable "azs" {
  type        = list(string)
  description = "Availability zones"
}