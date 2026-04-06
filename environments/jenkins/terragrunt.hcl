# ==============================================================================
# JENKINS ENVIRONMENT CONFIGURATION
# ==============================================================================

# Include the root configuration (S3 Backend, Provider, etc.)
include "root" {
  path = find_in_parent_folders("root.hcl")
}

# Link to the Jenkins Module we just built
terraform {
  source = "../../modules/jenkins"
}

# Dependency: We NEED the VPC outputs before we can build Jenkins
dependency "vpc" {
  config_path = "../vpc"
  
  # This prevents errors if you haven't run VPC apply yet
  mock_outputs = {
    vpc_id           = "vpc-12345"
    public_subnet_id = "subnet-12345"
    my_detected_ip      = "0.0.0.0/0"
  }
}

# ------------------------------------------------------------------------------
# INPUTS: Passing data from VPC to Jenkins
# ------------------------------------------------------------------------------
inputs = {
  vpc_id           = dependency.vpc.outputs.vpc_id
  public_subnet_id = dependency.vpc.outputs.public_subnet_ids[0] # Grab the first public subnet
  my_detected_ip   = dependency.vpc.outputs.my_detected_ip          # THE "MAGIC" CONNECTION
  instance_type    = "t3.large"
}