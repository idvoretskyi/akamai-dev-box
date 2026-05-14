# akamai-dev-box

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Validate](https://github.com/idvoretskyi/akamai-dev-box/actions/workflows/validate.yml/badge.svg)](https://github.com/idvoretskyi/akamai-dev-box/actions/workflows/validate.yml)
[![Trivy Security Scan](https://github.com/idvoretskyi/akamai-dev-box/actions/workflows/trivy.yml/badge.svg)](https://github.com/idvoretskyi/akamai-dev-box/actions/workflows/trivy.yml)

Pure OpenTofu configuration that spins up a remote Ubuntu 24.04 LTS dev box
on [Akamai Cloud](https://www.linode.com/) (formerly Linode).

The default configuration is intentionally minimal: vanilla Ubuntu 24.04, a
non-root user matching your local `$USER`, SSH key auth, a firewall, and a 2 GB
swap file. All optional layers (Docker, k3s, language toolchains, AI agents,
shell stack, VSCode tunnel) are available as opt-in variables.

## What's installed by default

| Layer          | Details                                                       |
| -------------- | ------------------------------------------------------------- |
| OS             | Ubuntu 24.04 LTS Noble (vanilla, no snap bloat, EOL 2029-04)  |
| Base utilities | git, curl, jq, unzip, ca-certificates, build-essential, wget  |
| User           | Non-root user matching local `$USER`, sudo NOPASSWD, SSH key  |
| Swap           | 2 GB swapfile                                                 |
| Firewall       | SSH (22) only inbound; all outbound allowed                   |

## Optional layers (opt-in via variables)

| Variable               | Default  | What it adds                                              |
| ---------------------- | -------- | --------------------------------------------------------- |
| `install_docker`       | `false`  | Docker CE + buildx + compose                              |
| `install_k3s`          | `false`  | k3s single-node server                                    |
| `install_languages`    | `[]`     | `go`, `node` (fnm), `python` (uv), `rust`                |
| `install_claude_code`  | `false`  | Claude Code CLI via npm                                   |
| `install_opencode`     | `false`  | OpenCode CLI via npm                                      |
| `install_vscode_tunnel`| `false`  | VSCode `code` CLI (tunnel activated manually on first SSH)|
| `install_shell_stack`  | `false`  | zsh + oh-my-zsh + tmux + fzf/zoxide/eza/delta/gh         |

## Prerequisites

- [OpenTofu](https://opentofu.org/) >= 1.6
- An [Akamai API token](https://cloud.linode.com/profile/tokens) with read/write
  on Linodes and Firewalls (set `LINODE_TOKEN`)
- An SSH public key (Ed25519 recommended)
- (Optional) `linode-cli` configured locally — region/type/image are inherited
  automatically

## Configuration sourcing

| Value           | Precedence                                                     |
| --------------- | -------------------------------------------------------------- |
| `region`        | `terraform.tfvars` → `~/.config/linode-cli` → `eu-west`       |
| `instance_type` | `terraform.tfvars` → `~/.config/linode-cli` → `g6-standard-4` |
| `image`         | `terraform.tfvars` → `~/.config/linode-cli` → `linode/ubuntu24.04` |
| `username`      | `TF_VAR_username` / `$DEVBOX_USER` → local `$USER` at apply time |

The non-root Linux user always matches your local `$USER`, so
`ssh $USER-dev-box` just works after the SSH config install step.

## Quick start

```sh
# 1. Configure
export LINODE_TOKEN="your-token-here"
cp tofu/terraform.tfvars.example tofu/terraform.tfvars
$EDITOR tofu/terraform.tfvars   # set authorized_keys + root_pass

# 2. Deploy
tofu -chdir=tofu init
tofu -chdir=tofu apply

# 3. Wait for cloud-init to finish (~2-3 min for vanilla)
eval "$(tofu -chdir=tofu output -raw wait_ready_command)"

# 4. Install SSH config (idempotent — safe to re-run after re-apply)
eval "$(tofu -chdir=tofu output -raw ssh_config_install_command)"

# 5. Connect
ssh $USER-dev-box
```

## Common operations

| What                          | Command                                                                  |
| ----------------------------- | ------------------------------------------------------------------------ |
| Show all outputs              | `tofu -chdir=tofu output`                                                |
| SSH as the non-root user      | `eval "$(tofu -chdir=tofu output -raw ssh_command_user)"`                |
| Tail cloud-init log           | `eval "$(tofu -chdir=tofu output -raw first_boot_log_command)"`          |
| Wait for cloud-init ready     | `eval "$(tofu -chdir=tofu output -raw wait_ready_command)"`              |
| Install ~/.ssh/config block   | `eval "$(tofu -chdir=tofu output -raw ssh_config_install_command)"`      |
| Remove ~/.ssh/config block    | `eval "$(tofu -chdir=tofu output -raw ssh_config_remove_command)"`       |
| Plan changes                  | `tofu -chdir=tofu plan`                                                  |
| Format + validate             | `tofu -chdir=tofu fmt -recursive && tofu -chdir=tofu validate`           |
| Tear it all down              | `tofu -chdir=tofu destroy`                                               |

## Variables

See `tofu/variables.tf` for the full list with descriptions and validation rules.

| Name                       | Default                                    | Notes                                                  |
| -------------------------- | ------------------------------------------ | ------------------------------------------------------ |
| `region`                   | from `linode-cli`, else `eu-west`          |                                                        |
| `instance_type`            | from `linode-cli`, else `g6-standard-4`    |                                                        |
| `image`                    | from `linode-cli`, else `linode/ubuntu24.04`|                                                       |
| `username`                 | local `$USER` at apply time                | Non-root user; override via `TF_VAR_username`          |
| `instance_label`           | `<username>-dev-box`                       |                                                        |
| `hostname`                 | (instance label)                           |                                                        |
| `timezone`                 | `UTC`                                      |                                                        |
| `authorized_keys`          | `[]`                                       | Required for SSH access                                |
| `root_pass`                | (required)                                 | API requires it; SSH key auth is used in practice      |
| `create_firewall`          | `true`                                     |                                                        |
| `allowed_ssh_cidrs_ipv4/6` | open                                       | Restrict to your own IPs in production                 |
| `expose_web`               | `false`                                    | Open inbound 80/443                                    |
| `expose_k3s_api`           | `false`                                    | Open inbound 6443                                      |
| `install_docker`           | `false`                                    |                                                        |
| `install_k3s`              | `false`                                    |                                                        |
| `k3s_disable_components`   | `["traefik","servicelb"]`                  | Only relevant when `install_k3s = true`                |
| `install_languages`        | `[]`                                       | `go`, `node`, `python`, `rust`                         |
| `install_claude_code`      | `false`                                    |                                                        |
| `install_opencode`         | `false`                                    |                                                        |
| `install_vscode_tunnel`    | `false`                                    |                                                        |
| `install_shell_stack`      | `false`                                    | zsh + omz + tmux + fzf/zoxide/eza/delta/gh             |

## Security notes

- **No inbound web ports by default.** SSH (22) is the only port open.
- **Restrict SSH** to your own networks via `allowed_ssh_cidrs_ipv4/6`.
- **Root login disabled** after cloud-init runs.
- **API token** lives only in `LINODE_TOKEN`. Scope it to Linodes RW + Firewalls RW.
- **State files** (`terraform.tfstate*`) are gitignored. Don't commit them.
- **Root password** is required by the Linode API but unused for login.
  Generate one with `openssl rand -base64 32`.

## Cost (rough, USD/month, varies by region)

| Plan            | vCPU / RAM / Disk  | ~/mo          |
| --------------- | ------------------ | ------------- |
| g6-standard-2   | 2 / 4 GB / 80 GB   | $24           |
| g6-standard-4   | 4 / 8 GB / 160 GB  | $48 (default) |
| g6-standard-6   | 4 / 16 GB / 320 GB | $96           |
| g6-dedicated-8  | 8 / 16 GB / 640 GB | $218          |

## Project layout

```
.
├── .github/
│   ├── dependabot.yml
│   ├── settings.yml
│   └── workflows/
│       ├── validate.yml          # tofu fmt + validate, shellcheck, actionlint
│       └── trivy.yml             # IaC + secrets scan
├── LICENSE
├── README.md
└── tofu/
    ├── cloud-init/
    │   ├── main.yaml.tpl         # cloud-config template
    │   └── scripts/
    │       ├── 10-base.sh        # apt baseline, swap
    │       ├── 20-docker.sh      # Docker CE
    │       ├── 30-k3s.sh         # k3s single-node server
    │       ├── 40-kube-tools.sh  # kubectl, helm, k9s, stern, yq
    │       ├── 50-langs.sh       # Go, Node/fnm, Python/uv, Rust
    │       ├── 60-agents.sh      # Claude Code + OpenCode via npm
    │       ├── 70-vscode-tunnel.sh # VSCode code CLI
    │       └── 80-shell.sh       # zsh + omz + tmux + modern CLIs
    ├── scripts/
    │   ├── read-laptop-user.sh   # emits local $USER as JSON
    │   └── read-linode-cli.sh    # reads ~/.config/linode-cli
    ├── main.tf
    ├── outputs.tf
    ├── terraform.tfvars.example
    ├── variables.tf
    └── versions.tf
```

## Tear down

```sh
tofu -chdir=tofu destroy
eval "$(tofu -chdir=tofu output -raw ssh_config_remove_command)"
```

## Contributing

PRs welcome. Before opening one:

```sh
tofu -chdir=tofu fmt -recursive
tofu -chdir=tofu init -backend=false
tofu -chdir=tofu validate
shellcheck tofu/cloud-init/scripts/*.sh tofu/scripts/*.sh
```

## License

[MIT](LICENSE).
