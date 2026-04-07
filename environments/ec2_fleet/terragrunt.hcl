include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../modules/ec2_fleet"
}

# This is the "Piping" that connects the two modules
dependency "vpc" {
  config_path = "../vpc"

  # ADD THIS BLOCK
  mock_outputs = {
    vpc_id             = "vpc-fake-id"
    public_subnet_ids  = ["subnet-fake-1", "subnet-fake-2"]
    private_subnet_ids = ["subnet-fake-3", "subnet-fake-4"]
    alb_sg_id          = "sg-fake-1"
    ec2_sg_id          = "sg-fake-2"
  }
  mock_outputs_allowed_terraform_commands = ["plan", "validate"]
}

inputs = {
  vpc_id             = dependency.vpc.outputs.vpc_id
  public_subnet_ids  = dependency.vpc.outputs.public_subnet_ids
  private_subnet_ids = dependency.vpc.outputs.private_subnet_ids
  alb_sg_id          = dependency.vpc.outputs.alb_sg_id
  ec2_sg_id          = dependency.vpc.outputs.ec2_sg_id
}