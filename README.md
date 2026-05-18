# akamai-dev-box

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Validate](https://github.com/idvoretskyi/akamai-dev-box/actions/workflows/validate.yml/badge.svg)](https://github.com/idvoretskyi/akamai-dev-box/actions/workflows/validate.yml)
[![Trivy Security Scan](https://github.com/idvoretskyi/akamai-dev-box/actions/workflows/trivy.yml/badge.svg)](https://github.com/idvoretskyi/akamai-dev-box/actions/workflows/trivy.yml)

OpenTofu config for a minimal Ubuntu 24.04 LTS dev box on [Akamai Cloud](https://www.linode.com/) (formerly Linode).

The box is intentionally vanilla: Ubuntu 24.04, a non-root user matching your local `$USER`, SSH key auth, and an SSH-only firewall. Install whatever else you need via `extra_packages` or after logging in.

## Prerequisites

- [OpenTofu](https://opentofu.org/) >= 1.6
- An [Akamai API token](https://cloud.linode.com/profile/tokens) with read/write on Linodes and Firewalls (exported as `LINODE_TOKEN`)
- An SSH public key (Ed25519 recommended)
- Optional: `linode-cli` configured locally — region / instance type / image are inherited from it

## Quick start

```sh
export LINODE_TOKEN="your-token-here"
cp tofu/terraform.tfvars.example tofu/terraform.tfvars
$EDITOR tofu/terraform.tfvars                                # authorized_keys + root_pass

tofu -chdir=tofu init
tofu -chdir=tofu apply

# Wait for cloud-init to finish (~1-2 min)
eval "$(tofu -chdir=tofu output -raw wait_ready_command)"

# Install ~/.ssh/config block (idempotent)
eval "$(tofu -chdir=tofu output -raw ssh_config_install_command)"

ssh "$USER-dev-box"
```

## Configuration

See `tofu/variables.tf` for the full list of inputs with defaults and validation. Common ones:

- `region`, `instance_type`, `image` — inherited from `~/.config/linode-cli` if present
- `username` — defaults to local `$USER`; override via `TF_VAR_username`
- `authorized_keys`, `root_pass` — required
- `allowed_ssh_cidrs_ipv4` / `_ipv6` — restrict SSH to your own networks in production
- `extra_packages` — additional apt packages installed on first boot

## Tear down

```sh
tofu -chdir=tofu destroy
eval "$(tofu -chdir=tofu output -raw ssh_config_remove_command)"
```

## License

[MIT](LICENSE).
