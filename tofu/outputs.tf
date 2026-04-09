output "instance_id" {
  description = "The ID of the Linode instance"
  value       = linode_instance.arch_dev.id
}

output "instance_label" {
  description = "The label of the Linode instance"
  value       = linode_instance.arch_dev.label
}

output "instance_status" {
  description = "The status of the Linode instance"
  value       = linode_instance.arch_dev.status
}

output "ipv4_address" {
  description = "The public IPv4 address of the instance"
  value       = length(linode_instance.arch_dev.ipv4) > 0 ? tolist(linode_instance.arch_dev.ipv4)[0] : null
}

output "ipv6_address" {
  description = "The IPv6 address of the instance"
  value       = linode_instance.arch_dev.ipv6
}

output "private_ip_address" {
  description = "The private IP address of the instance (if enabled)"
  value       = var.private_ip ? linode_instance.arch_dev.private_ip_address : null
}

output "region" {
  description = "The region where the instance is deployed"
  value       = linode_instance.arch_dev.region
}

output "instance_type" {
  description = "The type/plan of the instance"
  value       = linode_instance.arch_dev.type
}

output "ssh_command" {
  description = "SSH command to connect to the instance"
  value       = length(linode_instance.arch_dev.ipv4) > 0 ? "ssh root@${tolist(linode_instance.arch_dev.ipv4)[0]}" : "Instance IP not available"
}

output "firewall_id" {
  description = "The ID of the firewall (null if create_firewall is false)"
  value       = one(linode_firewall.arch_dev_fw[*].id)
}

output "firewall_status" {
  description = "The status of the firewall (null if create_firewall is false)"
  value       = one(linode_firewall.arch_dev_fw[*].status)
}
