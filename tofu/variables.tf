###############################################################################
# Instance basics
###############################################################################

variable "region" {
  description = "Akamai (Linode) region slug. Optional — inherits from ~/.config/linode-cli, then falls back to eu-west."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition     = var.region == null || can(regex("^[a-z]{2,3}-[a-z]+(-[0-9]+)?$", var.region))
    error_message = "Region must look like a valid Akamai region slug (e.g. eu-west, us-east, ap-south)."
  }
}

variable "instance_type" {
  description = "Akamai (Linode) instance plan. Optional — inherits from ~/.config/linode-cli, then falls back to g6-standard-4."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition     = var.instance_type == null || can(regex("^g[0-9]+-", var.instance_type))
    error_message = "Instance type must be a valid Linode plan slug (e.g. g6-standard-4, g6-dedicated-8)."
  }
}

variable "instance_label" {
  description = "Label for the Linode instance and base for derived names (firewall, hostname, tunnel). Defaults to <username>-dev-box when null."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition     = var.instance_label == null || can(regex("^[a-zA-Z0-9][a-zA-Z0-9_-]{0,63}$", var.instance_label))
    error_message = "Instance label must start with a letter or digit and contain only letters, digits, hyphens, or underscores (max 64 chars)."
  }
}

variable "image" {
  description = "Akamai image slug. Optional — inherits from ~/.config/linode-cli, then falls back to linode/debian13 (Debian 13 Trixie). Supported: linode/debian13, linode/debian12, linode/ubuntu24.04, linode/ubuntu22.04."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition     = var.image == null || can(regex("^(linode|private)/", var.image))
    error_message = "Image must be a valid Akamai image slug starting with 'linode/' or 'private/'."
  }
}

variable "hostname" {
  description = "System hostname. Defaults to the instance label when empty."
  type        = string
  default     = ""

  validation {
    condition     = var.hostname == "" || can(regex("^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$", var.hostname))
    error_message = "Hostname must be a valid DNS label (lowercase letters, digits, hyphens, 1-63 chars, not starting/ending with hyphen)."
  }
}

variable "timezone" {
  description = "IANA timezone for the box (e.g. UTC, Europe/Kyiv, America/New_York)."
  type        = string
  default     = "UTC"

  validation {
    condition     = can(regex("^[A-Za-z]+(/[A-Za-z_+-]+){0,2}$", var.timezone))
    error_message = "Timezone must look like a valid IANA timezone (e.g. UTC, Europe/Kyiv)."
  }
}

variable "tags" {
  description = "Tags to apply to the instance and firewall."
  type        = list(string)
  default     = ["dev", "devbox", "k3s", "debian"]
}

variable "private_ip" {
  description = "Enable a private IP on the instance."
  type        = bool
  default     = false
}

variable "backups_enabled" {
  description = "Enable Akamai automated backups (additional cost)."
  type        = bool
  default     = false
}

###############################################################################
# User / SSH
###############################################################################

variable "username" {
  description = "Non-root Linux user to create on the box. Defaults to the local $USER at apply time (override via TF_VAR_username or $DEVBOX_USER). Must be a valid Linux username."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition     = var.username == null || can(regex("^[a-z_][a-z0-9_-]{0,31}$", var.username))
    error_message = "Username must be a valid Linux username (start with lowercase letter or underscore, up to 32 chars)."
  }
}

variable "authorized_keys" {
  description = "List of SSH public keys authorised for the non-root user. Ed25519 recommended."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for key in var.authorized_keys : can(regex("^(ssh-(rsa|ed25519|dss)|ecdsa-sha2-nistp(256|384|521)) ", key))])
    error_message = "Each authorized key must be a valid SSH public key (ssh-rsa, ssh-ed25519, ssh-dss, ecdsa-sha2-nistp*)."
  }
}

variable "root_pass" {
  description = "Root password (required by the Linode API, but SSH key auth is used for access). Generate with `openssl rand -base64 32`."
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.root_pass) >= 16
    error_message = "Root password must be at least 16 characters long."
  }
}

###############################################################################
# Firewall
###############################################################################

variable "create_firewall" {
  description = "Create and attach a Cloud Firewall."
  type        = bool
  default     = true
}

variable "allowed_ssh_cidrs_ipv4" {
  description = "IPv4 CIDRs allowed to access SSH (port 22). Restrict to your own IP for production use."
  type        = list(string)
  default     = ["0.0.0.0/0"]

  validation {
    condition     = alltrue([for cidr in var.allowed_ssh_cidrs_ipv4 : can(cidrhost(cidr, 0))])
    error_message = "Each entry must be a valid IPv4 CIDR (e.g. 203.0.113.10/32)."
  }
}

variable "allowed_ssh_cidrs_ipv6" {
  description = "IPv6 CIDRs allowed to access SSH (port 22)."
  type        = list(string)
  default     = ["::/0"]

  validation {
    condition     = alltrue([for cidr in var.allowed_ssh_cidrs_ipv6 : can(cidrhost(cidr, 0))])
    error_message = "Each entry must be a valid IPv6 CIDR."
  }
}

variable "expose_web" {
  description = "Open inbound TCP 80 and 443 in the firewall. Off by default — VSCode tunnel and SSH cover most workflows."
  type        = bool
  default     = false
}

variable "expose_k3s_api" {
  description = "Open inbound TCP 6443 (k3s API) in the firewall. Off by default — fetch kubeconfig via SSH instead."
  type        = bool
  default     = false
}

variable "allowed_k3s_api_cidrs_ipv4" {
  description = "IPv4 CIDRs allowed to reach the k3s API (port 6443) when expose_k3s_api is true."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for cidr in var.allowed_k3s_api_cidrs_ipv4 : can(cidrhost(cidr, 0))])
    error_message = "Each entry must be a valid IPv4 CIDR."
  }
}

variable "allowed_k3s_api_cidrs_ipv6" {
  description = "IPv6 CIDRs allowed to reach the k3s API (port 6443) when expose_k3s_api is true."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for cidr in var.allowed_k3s_api_cidrs_ipv6 : can(cidrhost(cidr, 0))])
    error_message = "Each entry must be a valid IPv6 CIDR."
  }
}

###############################################################################
# Cloud-init toggles
###############################################################################

variable "extra_packages" {
  description = "Additional apt packages to install on first boot."
  type        = list(string)
  default     = []
}

variable "install_docker" {
  description = "Install Docker CE (with buildx and compose plugins) alongside k3s' bundled containerd."
  type        = bool
  default     = true
}

variable "install_k3s" {
  description = "Install single-node k3s server."
  type        = bool
  default     = true
}

variable "k3s_channel" {
  description = "k3s release channel (e.g. stable, latest, v1.31)."
  type        = string
  default     = "stable"
}

variable "k3s_disable_components" {
  description = "k3s components to disable. Traefik and ServiceLB are disabled by default so you can install your own ingress / LB."
  type        = list(string)
  default     = ["traefik", "servicelb"]
}

variable "install_languages" {
  description = "Language toolchains to install for the non-root user."
  type        = set(string)
  default     = ["go", "node", "python", "rust"]

  validation {
    condition     = length(setsubtract(var.install_languages, ["go", "node", "python", "rust"])) == 0
    error_message = "install_languages may only contain: go, node, python, rust."
  }
}

variable "install_claude_code" {
  description = "Install the Claude Code CLI (@anthropic-ai/claude-code) for the non-root user via npm."
  type        = bool
  default     = true
}

variable "install_opencode" {
  description = "Install the OpenCode CLI (opencode-ai) for the non-root user via npm."
  type        = bool
  default     = true
}

variable "install_vscode_tunnel" {
  description = "Install the VSCode `code` CLI on the box. Tunnel must be activated manually on first SSH (one-time GitHub device-code login)."
  type        = bool
  default     = true
}

variable "vscode_tunnel_name" {
  description = "Tunnel name used for https://vscode.dev/tunnel/<name>. Defaults to the hostname when empty."
  type        = string
  default     = ""

  validation {
    condition     = var.vscode_tunnel_name == "" || can(regex("^[a-z0-9][a-z0-9-]{0,38}$", var.vscode_tunnel_name))
    error_message = "Tunnel name must be 1-39 chars of lowercase letters, digits, or hyphens, starting with a letter or digit."
  }
}

variable "install_shell_stack" {
  description = "Install zsh + oh-my-zsh + powerlevel10k + tmux (TPM) + modern CLI essentials (fzf, zoxide, eza, delta, gh, btop, ncdu) for the non-root user. Sets zsh as the default login shell."
  type        = bool
  default     = true
}
