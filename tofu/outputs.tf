###############################################################################
# Instance identity
###############################################################################

output "instance_id" {
  description = "Linode instance ID."
  value       = linode_instance.dev_box.id
}

output "instance_label" {
  description = "Linode instance label."
  value       = linode_instance.dev_box.label
}

output "instance_status" {
  description = "Linode instance status."
  value       = linode_instance.dev_box.status
}

output "instance_type" {
  description = "Resolved instance plan."
  value       = linode_instance.dev_box.type
}

output "region" {
  description = "Resolved deployment region."
  value       = linode_instance.dev_box.region
}

output "image" {
  description = "Resolved image slug."
  value       = linode_instance.dev_box.image
}

###############################################################################
# Network
###############################################################################

output "ipv4_address" {
  description = "Public IPv4 address."
  value       = length(linode_instance.dev_box.ipv4) > 0 ? tolist(linode_instance.dev_box.ipv4)[0] : null
}

output "ipv6_address" {
  description = "IPv6 address."
  value       = linode_instance.dev_box.ipv6
}

output "private_ip_address" {
  description = "Private IPv4 address (if enabled)."
  value       = linode_instance.dev_box.private_ip_address
}

###############################################################################
# Firewall
###############################################################################

output "firewall_id" {
  description = "Firewall ID (null when create_firewall is false)."
  value       = one(linode_firewall.dev_box_fw[*].id)
}

output "firewall_status" {
  description = "Firewall status (null when create_firewall is false)."
  value       = one(linode_firewall.dev_box_fw[*].status)
}

###############################################################################
# Operational helpers (eval the -raw output to run them)
###############################################################################

locals {
  _ip   = length(linode_instance.dev_box.ipv4) > 0 ? tolist(linode_instance.dev_box.ipv4)[0] : ""
  _user = local.username
  _have = local._ip != ""
}

output "ssh_command" {
  description = "SSH as root."
  value       = local._have ? "ssh root@${local._ip}" : null
}

output "ssh_command_user" {
  description = "SSH as the non-root user."
  value       = local._have ? "ssh ${local._user}@${local._ip}" : null
}

output "first_boot_log_command" {
  description = "Tail cloud-init log on the box."
  value       = local._have ? "ssh ${local._user}@${local._ip} 'sudo tail -f /var/log/devbox-init.log'" : null
}

output "wait_ready_command" {
  description = "Poll until cloud-init finishes (writes /var/lib/devbox-init.done)."
  value       = local._have ? "until ssh -o StrictHostKeyChecking=accept-new ${local._user}@${local._ip} 'test -f /var/lib/devbox-init.done' 2>/dev/null; do echo waiting...; sleep 15; done; echo ready" : null
}

output "kubeconfig_fetch_command" {
  description = "Fetch kubeconfig locally and rewrite the server URL to the public IP."
  value       = local._have ? "scp ${local._user}@${local._ip}:~/.kube/config ./kubeconfig.devbox && sed -i.bak 's#https://127.0.0.1:6443#https://${local._ip}:6443#' ./kubeconfig.devbox && rm ./kubeconfig.devbox.bak" : null
}

output "k3s_status_command" {
  description = "Show k3s nodes and pods over SSH."
  value       = local._have ? "ssh ${local._user}@${local._ip} 'sudo k3s kubectl get nodes,pods -A'" : null
}

output "vscode_tunnel_url" {
  description = "VSCode tunnel URL once `code tunnel service install` has been run on the box."
  value       = var.install_vscode_tunnel ? "https://vscode.dev/tunnel/${local.tunnel_name}" : null
}

output "vscode_tunnel_setup_command" {
  description = "One-time interactive command to log in to GitHub and register the VSCode tunnel service."
  value = var.install_vscode_tunnel && local._have ? join(" && ", [
    "ssh -t ${local._user}@${local._ip} 'code tunnel user login --provider github",
    "sudo loginctl enable-linger ${local._user}",
    "code tunnel service install --name ${local.tunnel_name}'"
  ]) : null
}
