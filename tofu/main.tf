data "external" "current_user" {
  program = ["bash", "-c", "echo \"{\\\"username\\\": \\\"$(whoami)\\\"}\""]
}

locals {
  username = coalesce(var.username, data.external.current_user.result.username)

  inbound_rules = [
    {
      label    = "allow-ssh"
      protocol = "TCP"
      ports    = "22"
      ipv4     = var.allowed_ssh_cidrs_ipv4
      ipv6     = var.allowed_ssh_cidrs_ipv6
    },
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
  ]
}

resource "linode_instance" "dev_box" {
  label           = var.instance_label
  image           = var.image
  region          = var.region
  type            = var.instance_type
  authorized_keys = var.authorized_keys
  root_pass       = var.root_pass
  tags            = var.tags
  private_ip      = var.private_ip
  backups_enabled = var.backups_enabled
  metadata {
    user_data = base64encode(templatefile("${path.module}/cloud-init.yaml.tpl", {
      username = local.username
      ssh_keys = var.authorized_keys
    }))
  }

  # Optional StackScript configuration
  stackscript_id   = var.stackscript_id
  stackscript_data = var.stackscript_data

  # Lifecycle management
  lifecycle {
    ignore_changes = [
      # Ignore changes to root_pass after creation
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

  # Outbound policy is ACCEPT, so no explicit outbound rules are needed.

  linodes = [linode_instance.dev_box.id]
}
