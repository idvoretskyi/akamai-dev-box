# Deployment state is local by default and must be preserved outside Git
# (see the .gitignore state/tfvars rules and AGENTS.md safety boundaries).
# Declaring the backend explicitly avoids relying on OpenTofu's implicit
# default and makes a future backend migration an intentional, reviewed step.
terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
}
