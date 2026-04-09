output "instance_id" {
  description = "The ID of the Linode instance"
  value       = linode_instance.dev_box.id
}

output "instance_label" {
  description = "The label of the Linode instance"
  value       = linode_instance.dev_box.label
}

output "instance_status" {
  description = "The status of the Linode instance"
  value       = linode_instance.dev_box.status
}

output "ipv4_address" {
  description = "The public IPv4 address of the instance"
  value       = length(linode_instance.dev_box.ipv4) > 0 ? tolist(linode_instance.dev_box.ipv4)[0] : null
}

output "ipv6_address" {
  description = "The IPv6 address of the instance"
  value       = linode_instance.dev_box.ipv6
}

output "private_ip_address" {
  description = "The private IP address of the instance (if enabled)"
  value       = linode_instance.dev_box.private_ip_address
}

output "region" {
  description = "The region where the instance is deployed"
  value       = linode_instance.dev_box.region
}

output "instance_type" {
  description = "The type/plan of the instance"
  value       = linode_instance.dev_box.type
}

output "ssh_command" {
  description = "SSH command to connect to the instance"
  value       = length(linode_instance.dev_box.ipv4) > 0 ? "ssh root@${tolist(linode_instance.dev_box.ipv4)[0]}" : "Instance IP not available"
}

output "firewall_id" {
  description = "The ID of the firewall (null if create_firewall is false)"
  value       = one(linode_firewall.dev_box_fw[*].id)
}

output "firewall_status" {
  description = "The status of the firewall (null if create_firewall is false)"
  value       = one(linode_firewall.dev_box_fw[*].status)
}
