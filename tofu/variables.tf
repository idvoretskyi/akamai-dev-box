variable "region" {
  description = "Akamai (Linode) region to deploy the instance"
  type        = string
  default     = "us-east"

  validation {
    condition     = can(regex("^(us|eu|ap|ca|br|in|jp|au|sg|se|id|nl|fr|gb|de|it|es|mx|za|ng|ke|pk|bd|ph|vn|th|my|hk|tw|kr|nz)-", var.region))
    error_message = "Region must be a valid Akamai region slug (e.g. us-east, eu-west, ap-south)."
  }
}

variable "instance_type" {
  description = "Akamai (Linode) instance plan (e.g. g6-standard-2, g6-standard-6, g6-dedicated-8)"
  type        = string
  default     = "g6-standard-2" # 2 vCPUs, 4GB RAM, 80GB Storage

  validation {
    condition     = can(regex("^g[0-9]+-", var.instance_type))
    error_message = "Instance type must be a valid Linode plan slug (e.g. g6-standard-6, g6-dedicated-8)."
  }
}

variable "instance_label" {
  description = "Label for the Akamai instance"
  type        = string
  default     = "dev-box"

  validation {
    condition     = can(regex("^[a-zA-Z0-9][a-zA-Z0-9_-]{0,63}$", var.instance_label))
    error_message = "Instance label must start with a letter or digit and contain only letters, digits, hyphens, or underscores (max 64 chars)."
  }
}

variable "image" {
  description = "Akamai image slug to use (default: Ubuntu 24.04)"
  type        = string
  default     = "linode/ubuntu24.04"

  validation {
    condition     = can(regex("^(linode|private)/", var.image))
    error_message = "Image must be a valid Akamai image slug starting with 'linode/' or 'private/'."
  }
}

variable "username" {
  description = "Non-root user to create on the instance via cloud-init. Defaults to the local machine's current user."
  type        = string
  default     = null
  nullable    = true
}

variable "authorized_keys" {
  description = "List of SSH public keys for root user access"
  type        = list(string)
  default     = []
}

variable "root_pass" {
  description = "Root password for the instance (required by Linode, but SSH keys are recommended)"
  type        = string
  sensitive   = true
}

variable "tags" {
  description = "Tags to apply to the instance"
  type        = list(string)
  default     = ["dev", "ubuntu"]
}

variable "private_ip" {
  description = "Enable private IP address"
  type        = bool
  default     = false
}

variable "backups_enabled" {
  description = "Enable automated backups"
  type        = bool
  default     = false
}

variable "create_firewall" {
  description = "Whether to create a Linode Cloud Firewall and attach it to the instance"
  type        = bool
  default     = true
}

variable "allowed_ssh_cidrs_ipv4" {
  description = "List of IPv4 CIDRs allowed to access SSH. Defaults to all addresses."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "allowed_ssh_cidrs_ipv6" {
  description = "List of IPv6 CIDRs allowed to access SSH. Defaults to all addresses."
  type        = list(string)
  default     = ["::/0"]
}

variable "stackscript_id" {
  description = "Optional StackScript ID for instance configuration"
  type        = number
  default     = null
}

variable "stackscript_data" {
  description = "Data to pass to the StackScript"
  type        = map(string)
  default     = {}
  sensitive   = true
}
