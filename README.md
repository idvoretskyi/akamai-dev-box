# akamai-dev-box

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Validate](https://github.com/idvoretskyi/akamai-dev-box/actions/workflows/validate.yml/badge.svg)](https://github.com/idvoretskyi/akamai-dev-box/actions/workflows/validate.yml)
[![Trivy Security Scan](https://github.com/idvoretskyi/akamai-dev-box/actions/workflows/trivy.yml/badge.svg)](https://github.com/idvoretskyi/akamai-dev-box/actions/workflows/trivy.yml)

OpenTofu configuration that spins up a remote Ubuntu 24.04 LTS dev box on
[Akamai Cloud](https://www.linode.com/) (formerly Linode), reachable over SSH
and/or a [vscode.dev tunnel](https://code.visualstudio.com/docs/remote/tunnels).

## What's installed by default

The base image always includes: `git`, `curl`, `jq`, `unzip`, `build-essential`, swap, and sysctl tuning. Docker CE is the only optional layer that defaults to on.

Everything else is **opt-in** via variables:

| Layer              | Variable               | Default  | Tools                                                   |
| ------------------ | ---------------------- | -------- | ------------------------------------------------------- |
| Container runtime  | `install_docker`       | `true`   | Docker CE (+ buildx, compose)                           |
| Kubernetes         | `install_k3s`          | `false`  | k3s single-node + kubectl, helm, k9s, stern, yq         |
| Languages          | `install_languages`    | `[]`     | go, node (fnm), python (uv), rust                       |
| AI agents          | `install_claude_code`  | `false`  | `@anthropic-ai/claude-code`                             |
|                    | `install_opencode`     | `false`  | OpenCode                                                |
| Editor             | `install_vscode_tunnel`| `false`  | VSCode `code` CLI + tunnel                              |
| Shell              | `install_shell_stack`  | `false`  | zsh + oh-my-zsh, tmux, fzf, zoxide, eza, delta, gh     |

## Prerequisites

- [OpenTofu](https://opentofu.org/) >= 1.6
- An [Akamai API token](https://cloud.linode.com/profile/tokens) with Linodes + Firewalls read/write (set `LINODE_TOKEN`)
- An Ed25519 SSH public key
- A GitHub account for the one-time VSCode tunnel device-code login
- (Optional) `linode-cli` configured locally — region/type/image are inherited automatically

## Quick start

```sh
# 1. Configure
export LINODE_TOKEN="your-token-here"
cp tofu/terraform.tfvars.example tofu/terraform.tfvars
$EDITOR tofu/terraform.tfvars   # set authorized_keys + root_pass

# 2. Deploy
tofu -chdir=tofu init
tofu -chdir=tofu apply

# 3. Wait for cloud-init to finish (10–15 min)
eval "$(tofu -chdir=tofu output -raw wait_ready_command)"

# 4. Install SSH config (idempotent — safe to re-run after re-apply)
eval "$(tofu -chdir=tofu output -raw ssh_config_install_command)"

# 5. Connect
ssh $USER-dev-box

# 6. Start a tmux session
tmux new -s dev

# 7. One-time VSCode tunnel setup (interactive GitHub device-code login)
eval "$(tofu -chdir=tofu output -raw vscode_tunnel_setup_command)"

# 8. Open the tunnel
tofu -chdir=tofu output -raw vscode_tunnel_url
```

## Common operations

Outputs emit ready-to-run shell commands. Run `tofu -chdir=tofu output` to see all.

| What                        | Command                                                              |
| --------------------------- | -------------------------------------------------------------------- |
| SSH (non-root user)         | `eval "$(tofu -chdir=tofu output -raw ssh_command_user)"`            |
| Tail cloud-init log         | `eval "$(tofu -chdir=tofu output -raw first_boot_log_command)"`      |
| Wait for cloud-init ready   | `eval "$(tofu -chdir=tofu output -raw wait_ready_command)"`          |
| Install `~/.ssh/config`     | `eval "$(tofu -chdir=tofu output -raw ssh_config_install_command)"`  |
| Remove `~/.ssh/config`      | `eval "$(tofu -chdir=tofu output -raw ssh_config_remove_command)"`   |
| Fetch kubeconfig locally    | `eval "$(tofu -chdir=tofu output -raw kubeconfig_fetch_command)"`    |
| VSCode tunnel setup         | `eval "$(tofu -chdir=tofu output -raw vscode_tunnel_setup_command)"` |
| Open tunnel URL             | `open "$(tofu -chdir=tofu output -raw vscode_tunnel_url)"`           |
| Destroy                     | `tofu -chdir=tofu destroy`                                           |

After fetching kubeconfig:

```sh
export KUBECONFIG="$PWD/kubeconfig.devbox"
kubectl get nodes
```

## Variables

See `tofu/variables.tf` for the full list. Key variables:

| Name                       | Default                                 | Notes                                            |
| -------------------------- | --------------------------------------- | ------------------------------------------------ |
| `authorized_keys`          | `[]`                                    | Required for SSH access                          |
| `root_pass`                | (required)                              | API requirement; generate with `openssl rand -base64 32` |
| `region`                   | from `linode-cli`, else `eu-west`       |                                                  |
| `instance_type`            | from `linode-cli`, else `g6-standard-4` | 4 vCPU / 8 GB minimum recommended               |
| `allowed_ssh_cidrs_ipv4/6` | open                                    | Restrict to your IPs in production               |
| `install_docker`           | `true`                                  |                                                  |
| `install_k3s`              | `false`                                 |                                                  |
| `install_languages`        | `[]`                                    | Add `"go"`, `"node"`, `"python"`, `"rust"` as needed |
| `install_claude_code`      | `false`                                 |                                                  |
| `install_opencode`         | `false`                                 |                                                  |
| `install_vscode_tunnel`    | `false`                                 | Requires one-time interactive login              |
| `install_shell_stack`      | `false`                                 | zsh + tmux + modern CLIs                        |

## Security notes

- Only SSH (22) is open by default; VSCode uses an outbound tunnel, so 80/443/6443 stay closed.
- Restrict SSH via `allowed_ssh_cidrs_ipv4/6`.
- Root login is disabled after cloud-init.
- Scope `LINODE_TOKEN` to Linodes RW + Firewalls RW.
- State files (`terraform.tfstate*`) are gitignored — don't commit them.

## Cost (rough, USD/month)

| Plan           | vCPU / RAM / Disk  | ~/mo          |
| -------------- | ------------------ | ------------- |
| g6-standard-2  | 2 / 4 GB / 80 GB   | $24           |
| g6-standard-4  | 4 / 8 GB / 160 GB  | $48 (default) |
| g6-standard-6  | 4 / 16 GB / 320 GB | $96           |
| g6-dedicated-8 | 8 / 16 GB / 640 GB | $218          |

Add ~$2/mo if `backups_enabled = true`.

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
