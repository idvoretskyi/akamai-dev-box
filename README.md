# akamai-dev-box

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Validate](https://github.com/idvoretskyi/akamai-dev-box/actions/workflows/validate.yml/badge.svg)](https://github.com/idvoretskyi/akamai-dev-box/actions/workflows/validate.yml)
[![Trivy Security Scan](https://github.com/idvoretskyi/akamai-dev-box/actions/workflows/trivy.yml/badge.svg)](https://github.com/idvoretskyi/akamai-dev-box/actions/workflows/trivy.yml)

OpenTofu config for an Ubuntu 24.04 dev box on [Akamai Cloud](https://www.linode.com/). **g6-standard-4** (4 vCPU / 8 GB / 160 GB, $48/mo) by default. Ready ~2–3 min after `tofu apply`.

## What's included

**Shell:** zsh + [starship](https://starship.rs) (Nord) + tmux (Nord), fzf, zoxide, eza, bat, ripgrep, fd, jq, git-delta, htop, ncdu, tldr, direnv, tree.

**Dev CLIs:** gh, VS Code (`code tunnel`), Claude Code, opencode, mise, kubectl, opentofu, linode-cli.

**System:** zram (RAM/2, zstd), earlyoom, k3s disabled by default (`k3s-up` / `k3s-down`).

## Quick start

```sh
export LINODE_TOKEN="your-token-here"
cp tofu/terraform.tfvars.example tofu/terraform.tfvars
$EDITOR tofu/terraform.tfvars   # set authorized_keys + root_pass

tofu -chdir=tofu init && tofu -chdir=tofu apply
eval "$(tofu -chdir=tofu output -raw wait_ready_command)"
eval "$(tofu -chdir=tofu output -raw ssh_config_install_command)"
ssh "$USER-dev-box"
# authenticate on first login: claude | opencode | code tunnel | gh auth login
```

## Configuration

Key variables (`tofu/variables.tf`):

| Variable | Default | Notes |
|---|---|---|
| `region` / `instance_type` / `image` | from `~/.config/linode-cli` (keys: `region`, `type`, `image`) | fallback: `gb-lon` / `g6-standard-4` / `linode/ubuntu24.04` |
| `authorized_keys`, `root_pass` | — | required |
| `linode_token` | — | optional; pre-seeds `linode-cli` on the box |
| `allowed_ssh_cidrs_ipv4/6` | `0.0.0.0/0` | restrict in production |
| `extra_packages` | `[]` | additional apt packages |

Supported images: any `linode/ubuntu<NN>.<NN>` slug (e.g. `linode/ubuntu24.04`, default) or `private/*`.

## Scaling

```
g6-standard-2   2 vCPU /  4 GB /  80 GB — $24/mo
g6-standard-4   4 vCPU /  8 GB / 160 GB — $48/mo  ← default
g6-standard-6   6 vCPU / 16 GB / 320 GB — $96/mo
g6-dedicated-2  2 vCPU /  4 GB /  80 GB — $36/mo  (dedicated CPU)
g6-dedicated-4  4 vCPU /  8 GB / 160 GB — $72/mo  (dedicated CPU)
```

## Troubleshooting

```sh
eval "$(tofu -chdir=tofu output -raw first_boot_log_command)"
# /var/lib/devbox-init.done → success  |  .failed → check the log
```

## Tear down

```sh
tofu -chdir=tofu destroy && eval "$(tofu -chdir=tofu output -raw ssh_config_remove_command)"
```

## License

[MIT](LICENSE).
