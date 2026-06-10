###############################################################################
# Source defaults from the local linode-cli config when variables are unset.
# Precedence: terraform.tfvars / -var  ->  ~/.config/linode-cli  ->  fallback.
# The deploy username is derived from the local $USER at plan/apply time.
###############################################################################

provider "linode" {
  # When var.linode_token is null (the default), the provider falls through to
  # the LINODE_TOKEN environment variable, which is the recommended auth method.
  # Set linode_token in terraform.tfvars only if you prefer var-based auth;
  # the Linode provider v3.x treats an explicit null identically to omission.
  token = var.linode_token
}

data "external" "linode_cli" {
  program = ["bash", "${path.module}/scripts/read-linode-cli.sh"]
}

data "external" "local_user" {
  program = ["bash", "${path.module}/scripts/read-local-user.sh"]
}

locals {
  cli = data.external.linode_cli.result

  region        = coalesce(var.region, try(local.cli.region, ""), "gb-lon")
  instance_type = coalesce(var.instance_type, try(local.cli.type, ""), "g6-standard-4")
  image         = coalesce(var.image, try(local.cli.image, ""), "linode/ubuntu26.04")

  username = coalesce(var.username, data.external.local_user.result.username)
  instance = coalesce(var.instance_label, "${local.username}-dev-box")
  hostname = var.hostname == "" ? local.instance : var.hostname

  cloud_init = templatefile("${path.module}/cloud-init/main.yaml.tpl", {
    username        = local.username
    hostname        = local.hostname
    timezone        = var.timezone
    ssh_keys        = var.authorized_keys
    extra_packages  = var.extra_packages
    seed_linode_cli = var.seed_linode_cli
    linode_token    = var.linode_token
    region          = local.region
    instance_type   = local.instance_type
    image           = local.image
    dotfiles_repo   = var.dotfiles_repo
    git_user_name   = var.git_user_name
    git_user_email  = var.git_user_email
  })
}

resource "linode_instance" "dev_box" {
  label           = local.instance
  image           = local.image
  region          = local.region
  type            = local.instance_type
  authorized_keys = var.authorized_keys
  root_pass       = var.root_pass
  tags            = var.tags
  private_ip      = var.private_ip
  backups_enabled = var.backups_enabled

  metadata {
    user_data = base64encode(local.cloud_init)
  }

  lifecycle {
    precondition {
      condition     = can(regex("^[a-z_][a-z0-9_-]{0,31}$", local.username))
      error_message = "Resolved deploy username '${local.username}' is not a valid Linux username. Set TF_VAR_username or ensure your local $USER is a valid Linux username (lowercase, max 32 chars)."
    }
    precondition {
      condition     = can(regex("^(linode/ubuntu[0-9]+\\.[0-9]+|private/)", local.image))
      error_message = "Unsupported image '${local.image}'. Supported: any linode/ubuntu<NN>.<NN> slug (e.g. linode/ubuntu26.04) or private/ image."
    }
    ignore_changes = [root_pass]
  }
}

resource "linode_firewall" "dev_box_fw" {
  count = var.create_firewall ? 1 : 0

  label = "${local.instance}-firewall"
  tags  = var.tags

  inbound_policy  = "DROP"
  outbound_policy = "ACCEPT"

  inbound {
    label    = "allow-ssh"
    action   = "ACCEPT"
    protocol = "TCP"
    ports    = "22"
    ipv4     = var.allowed_ssh_cidrs_ipv4
    ipv6     = var.allowed_ssh_cidrs_ipv6
  }

  linodes = [linode_instance.dev_box.id]
}
