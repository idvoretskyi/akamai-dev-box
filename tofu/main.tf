###############################################################################
# Source defaults from the local linode-cli config when variables are unset.
# Precedence: terraform.tfvars / -var  ->  ~/.config/linode-cli  ->  fallback.
###############################################################################

data "external" "linode_cli" {
  program = ["bash", "${path.module}/scripts/read-linode-cli.sh"]
}

locals {
  cli = data.external.linode_cli.result

  region        = coalesce(var.region, try(local.cli.region, ""), "us-east")
  instance_type = coalesce(var.instance_type, try(local.cli.type, ""), "g6-standard-4")
  image         = coalesce(var.image, try(local.cli.image, ""), "linode/ubuntu25.10")

  username     = coalesce(var.username, "devuser")
  hostname     = var.hostname == "" ? var.instance_label : var.hostname
  tunnel_name  = var.vscode_tunnel_name == "" ? local.hostname : var.vscode_tunnel_name
  scripts_path = "${path.module}/cloud-init/scripts"

  # Order matters: each script is idempotent and gated by its toggle in env.
  scripts = [
    "10-base.sh",
    "20-docker.sh",
    "30-k3s.sh",
    "40-kube-tools.sh",
    "50-langs.sh",
    "60-agents.sh",
    "70-vscode-tunnel.sh",
  ]

  script_files = { for s in local.scripts : s => file("${local.scripts_path}/${s}") }

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
    scripts            = local.scripts
    script_files       = local.script_files
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
  label           = var.instance_label
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
    ignore_changes = [
      root_pass,
    ]
  }
}

resource "linode_firewall" "dev_box_fw" {
  count = var.create_firewall ? 1 : 0

  label = "${var.instance_label}-firewall"
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
