# akamai-dev-box

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Trivy Security Scan](https://github.com/idvoretskyi/akamai-dev-box/actions/workflows/trivy.yml/badge.svg)](https://github.com/idvoretskyi/akamai-dev-box/actions/workflows/trivy.yml)

OpenTofu configuration for deploying an Ubuntu 24.04 development box on [Akamai Cloud](https://www.linode.com/) (formerly Linode).

## What it provisions

- A Linode instance running Ubuntu 24.04
- A Cloud Firewall with SSH (22), HTTP (80), and HTTPS (443) inbound rules (optional)

## Prerequisites

- [OpenTofu](https://opentofu.org/) >= 1.0
- An [Akamai API token](https://cloud.linode.com/profile/tokens) with read/write access to Linodes and Firewalls
- Your SSH public key

## Usage

```sh
# 1. Set your API token
export LINODE_TOKEN="your-token-here"

# 2. Configure variables
cp tofu/terraform.tfvars.example tofu/terraform.tfvars
# Edit tofu/terraform.tfvars with your values

# 3. Deploy
cd tofu
tofu init
tofu plan
tofu apply
```

## Connect

```sh
ssh root@$(tofu -chdir=tofu output -raw ipv4_address)
```

## Variables

| Name | Description | Default |
| ---- | ----------- | ------- |
| `region` | Akamai region slug | `us-east` |
| `instance_type` | Instance plan | `g6-standard-2` |
| `instance_label` | Instance label | `dev-box` |
| `image` | Image slug | `linode/ubuntu24.04` |
| `username` | Non-root user to create via cloud-init | auto-detected |
| `authorized_keys` | SSH public keys | `[]` |
| `root_pass` | Root password (required by API) | -- |
| `tags` | Resource tags | `["dev", "ubuntu"]` |
| `private_ip` | Enable private IP | `false` |
| `backups_enabled` | Enable automated backups | `false` |
| `create_firewall` | Create and attach a Cloud Firewall | `true` |
| `allowed_ssh_cidrs_ipv4` | IPv4 CIDRs allowed for SSH access | `["0.0.0.0/0"]` |
| `allowed_ssh_cidrs_ipv6` | IPv6 CIDRs allowed for SSH access | `["::/0"]` |
| `stackscript_id` | Optional StackScript ID | `null` |
| `stackscript_data` | Data passed to the StackScript | `{}` |

## Destroy

```sh
tofu -chdir=tofu destroy
```
