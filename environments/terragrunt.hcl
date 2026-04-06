# ------------------------------------------------------------------------------
# ROOT TERRAGRUNT: Global Remote State Configuration
# ------------------------------------------------------------------------------
remote_state {
  backend = "s3"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
  config = {
    bucket         = "my-devops-lab-state-meezohzahri007" # Unique bucket name
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    use_lockfile   = true                    # Prevents two people from deploying at once
    #dynamodb_table = "terraform-lock-table" # Prevents two people from deploying at once
  }
}


# Generate an AWS provider block in every child module automatically
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    provider "aws" {
      region = "us-east-1"
    }
  EOF
}

inputs = {
  # This function specifically finds the folder containing the .git directory
  project_root = get_repo_root()
}