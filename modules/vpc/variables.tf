variable "public_subnet_cidrs" {
  default = ["10.0.1.0/24", "10.0.2.0/24"] # For the ALB
}

variable "private_subnet_cidrs" {
  default = ["10.0.11.0/24", "10.0.12.0/24"] # For the 5 EC2s
}

variable "azs" {
    type        = list(string)
    default     = ["us-east-1a", "us-east-1b"] # Two different AZs
}