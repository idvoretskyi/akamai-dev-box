# akamai-dev-box

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Trivy Security Scan](https://github.com/idvoretskyi/akamai-dev-box/actions/workflows/trivy.yml/badge.svg)](https://github.com/idvoretskyi/akamai-dev-box/actions/workflows/trivy.yml)

OpenTofu configuration for deploying an Ubuntu 24.04 development box on [Akamai Cloud](https://www.linode.com/) (formerly Linode).

## What it provisions

- A Linode compute instance running Ubuntu 24.04 with cloud-init provisioning
- A non-root user with sudo privileges and SSH key authentication
- Common development tools pre-installed (`git`, `curl`, `wget`, `jq`, `htop`, `tmux`, etc.)
- A Cloud Firewall with SSH (22), HTTP (80), and HTTPS (443) inbound rules (optional)
- Hardened SSH configuration (root login disabled, password authentication disabled)

## Project structure

```
.
├── .github/
│   ├── dependabot.yml            # Dependabot for provider + Actions updates
│   ├── settings.yml              # GitHub repository settings (probot/settings)
│   └── workflows/
│       └── trivy.yml             # CI: security scanning + OpenTofu validation
├── .gitignore
├── LICENSE                       # MIT License
├── Makefile                      # Make targets for common OpenTofu operations
├── README.md
└── tofu/                         # OpenTofu configuration
    ├── cloud-init.yaml.tpl       # Cloud-init template for user provisioning
    ├── main.tf                   # Main infrastructure (instance + firewall)
    ├── outputs.tf                # Output values (IPs, SSH commands, etc.)
    ├── provider.tf               # Linode provider configuration
    ├── terraform.tfvars.example  # Example variable values
    ├── variables.tf              # Input variable definitions with validations
    └── versions.tf               # Required provider versions
```

## Prerequisites

- [OpenTofu](https://opentofu.org/) >= 1.0
- An [Akamai API token](https://cloud.linode.com/profile/tokens) with read/write access to Linodes and Firewalls
- Your SSH public key (Ed25519 recommended)
- GNU Make (optional, for using Makefile targets)

## Usage

### Quick start

```sh
# 1. Set your API token
export LINODE_TOKEN="your-token-here"

# 2. Configure variables
cp tofu/terraform.tfvars.example tofu/terraform.tfvars
# Edit tofu/terraform.tfvars with your values

# 3. Initialize and deploy
make init
make plan
make apply
```

### Using OpenTofu directly

If you prefer not to use Make:

```sh
export LINODE_TOKEN="your-token-here"

tofu -chdir=tofu init
tofu -chdir=tofu plan
tofu -chdir=tofu apply
```

### Makefile targets

Run `make help` to see all available targets:

| Target | Description |
| ------ | ----------- |
| `make help` | Show all available targets |
| `make init` | Initialize OpenTofu working directory |
| `make plan` | Preview infrastructure changes |
| `make apply` | Apply infrastructure changes (interactive) |
| `make apply-auto` | Apply infrastructure changes (non-interactive) |
| `make destroy` | Destroy all managed infrastructure (interactive) |
| `make destroy-auto` | Destroy all managed infrastructure (non-interactive) |
| `make fmt` | Format all `.tf` files |
| `make validate` | Validate configuration files |
| `make check` | Run format check and validation (used in CI) |
| `make output` | Show all outputs from the current state |
| `make clean` | Remove local `.terraform` directory and lock file |
| `make setup` | Full setup: init + validate |

## Connect

After deployment, connect to your instance using the non-root user (recommended):

```sh
# Using the output directly
$(tofu -chdir=tofu output -raw ssh_command_user)

# Or manually
ssh <username>@$(tofu -chdir=tofu output -raw ipv4_address)
```

To connect as root (not recommended in production):

```sh
$(tofu -chdir=tofu output -raw ssh_command)
```

You can also view all outputs at once:

```sh
make output
```

> **Note:** Cloud-init disables root SSH login after provisioning. Use the
> non-root user configured via the `username` variable for regular access.

## Variables

| Name | Description | Default |
| ---- | ----------- | ------- |
| `region` | Akamai region slug | `us-east` |
| `instance_type` | Instance plan | `g6-standard-2` |
| `instance_label` | Instance label | `dev-box` |
| `image` | Image slug | `linode/ubuntu24.04` |
| `username` | Non-root user to create via cloud-init | `devuser` |
| `authorized_keys` | SSH public keys | `[]` |
| `root_pass` | Root password (required by API, min 16 chars) | -- |
| `tags` | Resource tags | `["dev", "ubuntu"]` |
| `private_ip` | Enable private IP | `false` |
| `backups_enabled` | Enable automated backups | `false` |
| `create_firewall` | Create and attach a Cloud Firewall | `true` |
| `allowed_ssh_cidrs_ipv4` | IPv4 CIDRs allowed for SSH access | `["0.0.0.0/0"]` |
| `allowed_ssh_cidrs_ipv6` | IPv6 CIDRs allowed for SSH access | `["::/0"]` |
| `stackscript_id` | Optional StackScript ID | `null` |
| `stackscript_data` | Data passed to the StackScript | `{}` |

## Security best practices

### API token

- **Never commit your API token.** Use the `LINODE_TOKEN` environment variable.
- Consider using a secrets manager or a `.env` file (already in `.gitignore`).
- Create a token with the minimum required permissions (Linodes: Read/Write, Firewalls: Read/Write).

### SSH keys

- Use Ed25519 keys for the strongest security:
  ```sh
  ssh-keygen -t ed25519 -C "your-email@example.com"
  ```
- Add your public key to `authorized_keys` in `terraform.tfvars`.
- The cloud-init configuration disables password-based SSH access.

### Firewall and network

- The Cloud Firewall defaults to a **DROP** inbound policy, only allowing SSH, HTTP, and HTTPS.
- **Restrict SSH access** by setting `allowed_ssh_cidrs_ipv4` and `allowed_ssh_cidrs_ipv6` to your specific IP ranges instead of the default `0.0.0.0/0`:
  ```hcl
  allowed_ssh_cidrs_ipv4 = ["203.0.113.10/32"]
  allowed_ssh_cidrs_ipv6 = ["2001:db8::1/128"]
  ```
- Root SSH login is disabled after cloud-init runs. Use the non-root user for access.

### Passwords

- The `root_pass` variable is required by the Linode API but SSH key authentication is strongly recommended.
- Generate a strong random password:
  ```sh
  openssl rand -base64 32
  ```
- The password must be at least 16 characters.

## Destroy

```sh
make destroy
```

Or non-interactively:

```sh
make destroy-auto
```

## Contributing

Contributions are welcome. Please open an issue or submit a pull request.

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/my-change`)
3. Make your changes and run `make check` to validate
4. Commit and push your branch
5. Open a pull request

## License

This project is licensed under the [MIT License](LICENSE).
