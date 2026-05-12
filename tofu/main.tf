###############################################################################
# Source defaults from the local linode-cli config when variables are unset.
# Precedence: terraform.tfvars / -var  ->  ~/.config/linode-cli  ->  fallback.
# The deploy username is derived from the local $USER at plan/apply time.
###############################################################################

data "external" "linode_cli" {
  program = ["bash", "${path.module}/scripts/read-linode-cli.sh"]
}

data "external" "laptop_user" {
  program = ["bash", "${path.module}/scripts/read-laptop-user.sh"]
}

locals {
  cli = data.external.linode_cli.result

  region        = coalesce(var.region, try(local.cli.region, ""), "eu-west")
  instance_type = coalesce(var.instance_type, try(local.cli.type, ""), "g6-standard-4")
  image         = coalesce(var.image, try(local.cli.image, ""), "linode/debian13")

  username    = coalesce(var.username, data.external.laptop_user.result.username)
  instance    = coalesce(var.instance_label, "${local.username}-dev-box")
  hostname    = var.hostname == "" ? local.instance : var.hostname
  tunnel_name = var.vscode_tunnel_name == "" ? local.hostname : var.vscode_tunnel_name
  # Git ref used to fetch scripts from GitHub at boot time.
  # Uses the current HEAD commit SHA for a stable, pinned reference.
  git_ref = "c6a15d636852f71e09f9636546b67c5f48fa041e"

  cloud_init = templatefile("${path.module}/cloud-init/main.yaml.tpl", {
    username           = local.username
    hostname           = local.hostname
    timezone           = var.timezone
    ssh_keys           = var.authorized_keys
    extra_packages     = var.extra_packages
    install_docker     = var.install_docker
    install_k3s        = var.install_k3s
    k3s_channel        = var.k3s_channel
    k3s_disable        = var.k3s_disable_components
    install_languages  = sort(tolist(var.install_languages))
    install_claude     = var.install_claude_code
    install_opencode   = var.install_opencode
    install_vscode     = var.install_vscode_tunnel
    vscode_tunnel_name = local.tunnel_name
    install_shell      = var.install_shell_stack
    git_ref            = local.git_ref
  })

  # Firewall: SSH always; HTTP/HTTPS only if expose_web; 6443 only if expose_k3s_api.
  inbound_rules = concat(
    [{
      label    = "allow-ssh"
      protocol = "TCP"
      ports    = "22"
      ipv4     = var.allowed_ssh_cidrs_ipv4
      ipv6     = var.allowed_ssh_cidrs_ipv6
    }],
    var.expose_web ? [
      {
        label    = "allow-http"
        protocol = "TCP"
        ports    = "80"
        ipv4     = ["0.0.0.0/0"]
        ipv6     = ["::/0"]
      },
      {
        label    = "allow-https"
        protocol = "TCP"
        ports    = "443"
        ipv4     = ["0.0.0.0/0"]
        ipv6     = ["::/0"]
      },
    ] : [],
    var.expose_k3s_api ? [{
      label    = "allow-k3s-api"
      protocol = "TCP"
      ports    = "6443"
      ipv4     = var.allowed_k3s_api_cidrs_ipv4
      ipv6     = var.allowed_k3s_api_cidrs_ipv6
    }] : [],
  )
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
      condition     = can(regex("^(linode/(debian1[23]|ubuntu(22\\.04|24\\.04))|private/)", local.image))
      error_message = "Unsupported image '${local.image}'. Supported images: linode/debian13, linode/debian12, linode/ubuntu24.04, linode/ubuntu22.04, or any private/ image."
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

  dynamic "inbound" {
    for_each = local.inbound_rules
    content {
      label    = inbound.value.label
      action   = "ACCEPT"
      protocol = inbound.value.protocol
      ports    = inbound.value.ports
      ipv4     = inbound.value.ipv4
      ipv6     = inbound.value.ipv6
    }
  }

  linodes = [linode_instance.dev_box.id]
}
