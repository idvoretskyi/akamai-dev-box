provider "linode" {
  # When var.linode_token is null (the default), the provider falls through to
  # the LINODE_TOKEN environment variable, which is the recommended auth method.
  # Set linode_token in terraform.tfvars only if you prefer var-based auth;
  # the Linode provider v3.x treats an explicit null identically to omission.
  token = var.linode_token
}
