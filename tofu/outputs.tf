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
  ip      = length(linode_instance.dev_box.ipv4) > 0 ? tolist(linode_instance.dev_box.ipv4)[0] : ""
  have_ip = local.ip != ""
}

output "ssh_command" {
  description = "SSH as root."
  value       = local.have_ip ? "ssh root@${local.ip}" : null
}

output "ssh_command_user" {
  description = "SSH as the non-root user."
  value       = local.have_ip ? "ssh ${local.username}@${local.ip}" : null
}

output "first_boot_log_command" {
  description = "Tail cloud-init log on the box."
  value       = local.have_ip ? "ssh ${local.username}@${local.ip} 'sudo tail -f /var/log/devbox-init.log'" : null
}

output "wait_ready_command" {
  description = "Poll until cloud-init finishes (or fails). Exits 0 on success, 1 on failure."
  value       = local.have_ip ? "until ssh -o StrictHostKeyChecking=accept-new ${local.username}@${local.ip} 'test -f /var/lib/devbox-init.done || test -f /var/lib/devbox-init.failed' 2>/dev/null; do echo waiting...; sleep 15; done; ssh ${local.username}@${local.ip} 'test -f /var/lib/devbox-init.done && echo ready || { echo FAILED - check /var/log/devbox-init.log; exit 1; }'" : null
}

output "kubeconfig_fetch_command" {
  description = "Fetch kubeconfig locally and rewrite the server URL to the public IP."
  value       = local.have_ip ? "scp ${local.username}@${local.ip}:~/.kube/config ./kubeconfig.devbox && sed -i.bak 's#https://127.0.0.1:6443#https://${local.ip}:6443#' ./kubeconfig.devbox && rm ./kubeconfig.devbox.bak" : null
}

output "k3s_status_command" {
  description = "Show k3s nodes and pods over SSH."
  value       = local.have_ip ? "ssh ${local.username}@${local.ip} 'sudo k3s kubectl get nodes,pods -A'" : null
}

output "vscode_tunnel_url" {
  description = "VSCode tunnel URL once the tunnel service has been installed on the box."
  value       = var.install_vscode_tunnel ? "https://vscode.dev/tunnel/${local.tunnel_name}" : null
}

output "vscode_tunnel_setup_command" {
  description = "One-time interactive command to log in to GitHub and register the VSCode tunnel service."
  value       = var.install_vscode_tunnel && local.have_ip ? "ssh -t ${local.username}@${local.ip} 'code tunnel user login --provider github && sudo loginctl enable-linger ${local.username} && code tunnel service install --name ${local.tunnel_name}'" : null
}

###############################################################################
# SSH config helpers
###############################################################################

output "ssh_config_snippet" {
  description = "~/.ssh/config block for this box. Append via ssh_config_install_command."
  value       = local.have_ip ? "# BEGIN akamai-dev-box\nHost $USER-dev-box\n  HostName ${local.ip}\n  User ${local.username}\n  IdentityFile ~/.ssh/id_ed25519\n  StrictHostKeyChecking accept-new\n# END akamai-dev-box" : null
}

output "ssh_config_install_command" {
  description = "Idempotently install the SSH config block into ~/.ssh/config (removes any previous block first)."
  value       = local.have_ip ? "sed -i.bak '/^# BEGIN akamai-dev-box$/,/^# END akamai-dev-box$/d' ~/.ssh/config 2>/dev/null; rm -f ~/.ssh/config.bak; printf '# BEGIN akamai-dev-box\\nHost %s-dev-box\\n  HostName ${local.ip}\\n  User ${local.username}\\n  IdentityFile ~/.ssh/id_ed25519\\n  StrictHostKeyChecking accept-new\\n# END akamai-dev-box\\n' \"$USER\" >> ~/.ssh/config; chmod 600 ~/.ssh/config" : null
}

output "ssh_config_remove_command" {
  description = "Remove the managed SSH config block on destroy."
  value       = "sed -i.bak '/^# BEGIN akamai-dev-box$/,/^# END akamai-dev-box$/d' ~/.ssh/config 2>/dev/null && rm -f ~/.ssh/config.bak && chmod 600 ~/.ssh/config"
}
