# akamai-dev-box

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Validate](https://github.com/idvoretskyi/akamai-dev-box/actions/workflows/validate.yml/badge.svg)](https://github.com/idvoretskyi/akamai-dev-box/actions/workflows/validate.yml)
[![Trivy Security Scan](https://github.com/idvoretskyi/akamai-dev-box/actions/workflows/trivy.yml/badge.svg)](https://github.com/idvoretskyi/akamai-dev-box/actions/workflows/trivy.yml)

OpenTofu configuration for a personal, always-on Ubuntu 26.04 LTS dev box on [Akamai Cloud](https://www.linode.com/), built to run hosted coding agents (opencode, Claude Code, Codex, GitHub Copilot). Connect over SSH, keep agents in tmux, and use it for builds, containers, and small CPU experiments.

Baseline: **g8-dedicated-16-4** (4 dedicated vCPUs, 16 GiB RAM, 160 GB disk), $0.21/hour, about $153/month, billed hourly with no monthly cap and metered outbound transfer ([details](docs/operations.md#billing)). Paid backups are off. GPU training and Kubeflow live in [akamai-lke-gpu-cluster](https://github.com/idvoretskyi/akamai-lke-gpu-cluster), not here.

## What's included

- **Shell:** zsh + oh-my-zsh, tmux, vim, git config from [dotfiles](https://github.com/idvoretskyi/dotfiles) (`dotfiles_repo`), plus fzf, zoxide, eza, bat, ripgrep, fd, jq, delta, htop, ncdu, tldr, direnv.
- **Dev CLIs:** gh, VS Code (`code tunnel`), Claude Code, opencode, mise, kubectl, opentofu, linode-cli. Codex and Copilot: install and log in yourself.
- **Containers:** Docker CE (buildx, compose) for devcontainers. k3s is installed but disabled; see [workloads](docs/workloads.md#optional-local-k3s).
- **System:** zram (RAM/2, zstd), earlyoom.

## Quick start

For a **new** instance only. For the existing box, see [Resize](docs/operations.md#resize-an-existing-instance).

```sh
export LINODE_TOKEN="your-token-here"
cp tofu/terraform.tfvars.example tofu/terraform.tfvars
$EDITOR tofu/terraform.tfvars   # set authorized_keys + root_pass

tofu -chdir=tofu init -lockfile=readonly
tofu -chdir=tofu plan -out=create.tfplan   # review resources and cost
tofu -chdir=tofu apply create.tfplan
eval "$(tofu -chdir=tofu output -raw wait_ready_command)"
eval "$(tofu -chdir=tofu output -raw ssh_config_install_command)"
ssh "$USER-dev-box"
# first login: claude | opencode | code tunnel | gh auth login
```

## Configuration

Precedence: explicit variable, then `~/.config/linode-cli`, then built-in fallback. Full list in `tofu/variables.tf`.

| Variable | Default | Notes |
|---|---|---|
| `region`, `instance_type`, `image` | linode-cli config, then `gb-lon` / `g8-dedicated-16-4` / `linode/ubuntu26.04` | example pins the plan |
| `authorized_keys`, `root_pass` | none | required |
| `dotfiles_repo` | idvoretskyi/dotfiles | `""` skips |
| `git_user_name`, `git_user_email` | unset | written to `~/.gitconfig.local` |
| `linode_token` | unset | or use `LINODE_TOKEN`; box seeding needs `seed_linode_cli = true` |
| `allowed_ssh_cidrs_ipv4/6` | `0.0.0.0/0`, `::/0` | restrict where practical |
| `backups_enabled` | `false` | paid backups are not part of the baseline |
| `extra_packages` | `[]` | extra apt packages |
| `deployment_user_data_base64` | unset | sensitive; for resizes only, see [operations](docs/operations.md#resize-an-existing-instance) |

Pin `region`, `username`, and `instance_label` for repeatable deployments. State uses the local backend (`tofu/backend.tf`). The instance sets `resize_disk = false` and `prevent_destroy = true`.

## Documentation

- [docs/operations.md](docs/operations.md): billing, network transfer, resize, intentional replacement
- [docs/workloads.md](docs/workloads.md): local LLMs, PyTorch, Kubernetes access, k3s
- [AGENTS.md](AGENTS.md): repository layout and safety boundaries

## Development checks

```sh
tofu -chdir=tofu fmt -check -recursive -diff
tofu -chdir=tofu init -backend=false -lockfile=readonly
tofu -chdir=tofu validate
scripts/check-cloud-init.sh          # needs tofu/terraform and python3 + PyYAML; shellcheck and cloud-init optional
git diff --check
```

These checks do not create or resize infrastructure. Editing the cloud-init templates changes the rendered `user_data`; for the existing instance, pin `deployment_user_data_base64` first (see [Resize an existing instance](docs/operations.md#resize-an-existing-instance)) or the plan will show a forced replacement, which `prevent_destroy` blocks.

## Troubleshooting

```sh
eval "$(tofu -chdir=tofu output -raw first_boot_log_command)"
# /var/lib/devbox-init.done = success, .failed = check the log
```

## Tear down

`prevent_destroy` blocks `tofu destroy` by design. Remove it as a reviewed change first, then:

```sh
tofu -chdir=tofu destroy && eval "$(tofu -chdir=tofu output -raw ssh_config_remove_command)"
```

## License

[MIT](LICENSE)
