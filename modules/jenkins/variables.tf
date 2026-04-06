variable "vpc_id" {
  description = "The ID of the VPC where Jenkins will live"
  type        = string
}

variable "public_subnet_id" {
  description = "The Public Subnet ID for the Jenkins EC2"
  type        = string
}

variable "my_detected_ip" {
  description = "Your home IP address (e.g., 1.2.3.4/32) to restrict access"
  type        = string
  default     = "0.0.0.0/0" # We will override this in Terragrunt for safety
}

variable "instance_type" {
  description = "Size of the Jenkins server"
  type        = string
  default     = "t3.large" # 2 vCPU, 4GB RAM - Minimum for smooth Jenkins
}