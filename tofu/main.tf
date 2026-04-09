data "external" "current_user" {
  program = ["bash", "-c", "echo \"{\\\"username\\\": \\\"$(whoami)\\\"}\""]
}

locals {
  username = coalesce(var.username, data.external.current_user.result.username)
}

resource "linode_instance" "arch_dev" {
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

resource "linode_firewall" "arch_dev_fw" {
  count = var.create_firewall ? 1 : 0

  label = "${var.instance_label}-firewall"
  tags  = var.tags

  inbound_policy  = "DROP"
  outbound_policy = "ACCEPT"

  inbound {
    label    = "allow-ssh"
    action   = "ACCEPT"
    protocol = "TCP"
    ports    = "22"
    ipv4     = ["0.0.0.0/0"]
    ipv6     = ["::/0"]
  }

  inbound {
    label    = "allow-http"
    action   = "ACCEPT"
    protocol = "TCP"
    ports    = "80"
    ipv4     = ["0.0.0.0/0"]
    ipv6     = ["::/0"]
  }

  inbound {
    label    = "allow-https"
    action   = "ACCEPT"
    protocol = "TCP"
    ports    = "443"
    ipv4     = ["0.0.0.0/0"]
    ipv6     = ["::/0"]
  }

  outbound {
    label    = "allow-all-outbound"
    action   = "ACCEPT"
    protocol = "TCP"
    ports    = "1-65535"
    ipv4     = ["0.0.0.0/0"]
    ipv6     = ["::/0"]
  }

  outbound {
    label    = "allow-all-udp-outbound"
    action   = "ACCEPT"
    protocol = "UDP"
    ports    = "1-65535"
    ipv4     = ["0.0.0.0/0"]
    ipv6     = ["::/0"]
  }

  outbound {
    label    = "allow-icmp-outbound"
    action   = "ACCEPT"
    protocol = "ICMP"
    ipv4     = ["0.0.0.0/0"]
    ipv6     = ["::/0"]
  }

  linodes = [linode_instance.arch_dev.id]
}
