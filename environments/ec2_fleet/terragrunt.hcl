include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../modules/ec2_fleet"
}

# This is the "Piping" that connects the two modules
dependency "vpc" {
  config_path = "../vpc"
}

inputs = {
  vpc_id             = dependency.vpc.outputs.vpc_id
  public_subnet_ids  = dependency.vpc.outputs.public_subnet_ids
  private_subnet_ids = dependency.vpc.outputs.private_subnet_ids
  alb_sg_id          = dependency.vpc.outputs.alb_sg_id
  ec2_sg_id          = dependency.vpc.outputs.ec2_sg_id
}