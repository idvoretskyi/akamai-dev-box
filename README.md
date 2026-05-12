# akamai-dev-box

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Validate](https://github.com/idvoretskyi/akamai-dev-box/actions/workflows/validate.yml/badge.svg)](https://github.com/idvoretskyi/akamai-dev-box/actions/workflows/validate.yml)
[![Trivy Security Scan](https://github.com/idvoretskyi/akamai-dev-box/actions/workflows/trivy.yml/badge.svg)](https://github.com/idvoretskyi/akamai-dev-box/actions/workflows/trivy.yml)

Pure OpenTofu configuration that spins up a remote Ubuntu 24.04 LTS dev box on
[Akamai Cloud](https://www.linode.com/) (formerly Linode), preloaded with k3s,
container tooling, CNCF CLIs, common language toolchains, and AI coding agents
(Claude Code + OpenCode). Intended to be used as a remote brain for
agentic-coding sessions and CNCF demo work, reached over SSH and/or
[vscode.dev tunnel](https://code.visualstudio.com/docs/remote/tunnels).

## What's installed

| Layer              | Tools                                                          |
| ------------------ | -------------------------------------------------------------- |
| OS                 | Ubuntu 24.04 LTS (Noble Numbat)                                |
| Container runtimes | Docker CE (+ buildx, compose), containerd (via k3s)            |
| Kubernetes         | k3s single-node (Traefik + ServiceLB disabled by default)      |
| Kube CLIs          | kubectl, helm, k9s, stern, cilium-cli, flux, argocd, yq        |
| Languages          | Go, Node LTS (via fnm), Python (via uv), Rust (rustup)         |
| AI agents          | Claude Code (`@anthropic-ai/claude-code`), OpenCode            |
| Editor             | VSCode `code` CLI + tunnel (`https://vscode.dev/tunnel/<name>`) |
| Base utilities     | git, tmux, jq, ripgrep, fd, bat, neovim, htop                  |

All toggles are exposed as variables — disable any layer you don't want.

## Architecture

```
  laptop ── SSH ─────────────┐
                             ├── Akamai VM ── k3s (single node)
  laptop ── VSCode tunnel ───┘                ── Docker
                       (outbound HTTPS only,
                        no inbound web ports required)
```

## Prerequisites

- [OpenTofu](https://opentofu.org/) >= 1.6
- An [Akamai API token](https://cloud.linode.com/profile/tokens) with read/write
  on Linodes and Firewalls (set `LINODE_TOKEN`)
- An Ed25519 SSH public key
- (Optional) `linode-cli` configured locally — its region/type/image are
  inherited automatically
- A GitHub account for the one-time VSCode tunnel device-code login

## Configuration sourcing

Three values are sourced automatically — no `terraform.tfvars` entry needed:

| Value         | Precedence                                                   |
| ------------- | ------------------------------------------------------------ |
| `region`      | `terraform.tfvars` → `~/.config/linode-cli` → `eu-west`     |
| `instance_type` | `terraform.tfvars` → `~/.config/linode-cli` → `g6-standard-4` |
| `image`       | `terraform.tfvars` → `~/.config/linode-cli` → `linode/ubuntu24.04` |
| `username`    | `TF_VAR_username` / `$DEVBOX_USER` → local `$USER` at apply time |

The non-root Linux user created on the box always matches your local `$USER`,
so `ssh $USER-dev-box` just works after the SSH config install step.

## Quick start

```sh
# 1. Configure
export LINODE_TOKEN="your-token-here"
cp tofu/terraform.tfvars.example tofu/terraform.tfvars
$EDITOR tofu/terraform.tfvars   # set authorized_keys + root_pass

# 2. Deploy
tofu -chdir=tofu init
tofu -chdir=tofu apply

# 3. Wait for cloud-init to finish (5–10 min)
eval "$(tofu -chdir=tofu output -raw wait_ready_command)"

# 4. Install SSH config (idempotent — safe to re-run after re-apply)
eval "$(tofu -chdir=tofu output -raw ssh_config_install_command)"

# 5. Connect
ssh $USER-dev-box

# 6. One-time VSCode tunnel setup (interactive GitHub device-code login)
eval "$(tofu -chdir=tofu output -raw vscode_tunnel_setup_command)"

# 7. Open the tunnel
tofu -chdir=tofu output -raw vscode_tunnel_url
```

## Common operations

All helpers live as outputs whose value is a ready-to-run shell command.

| What                          | Command                                                                  |
| ----------------------------- | ------------------------------------------------------------------------ |
| Show all outputs              | `tofu -chdir=tofu output`                                                |
| SSH as the non-root user      | `eval "$(tofu -chdir=tofu output -raw ssh_command_user)"`                |
| Tail cloud-init log           | `eval "$(tofu -chdir=tofu output -raw first_boot_log_command)"`          |
| Wait for cloud-init ready     | `eval "$(tofu -chdir=tofu output -raw wait_ready_command)"`              |
| Install ~/.ssh/config block   | `eval "$(tofu -chdir=tofu output -raw ssh_config_install_command)"`      |
| Remove ~/.ssh/config block    | `eval "$(tofu -chdir=tofu output -raw ssh_config_remove_command)"`       |
| Fetch kubeconfig locally      | `eval "$(tofu -chdir=tofu output -raw kubeconfig_fetch_command)"`        |
| k3s nodes + pods over SSH     | `eval "$(tofu -chdir=tofu output -raw k3s_status_command)"`              |
| VSCode tunnel setup (one-off) | `eval "$(tofu -chdir=tofu output -raw vscode_tunnel_setup_command)"`     |
| Open the tunnel URL           | `open "$(tofu -chdir=tofu output -raw vscode_tunnel_url)"`               |
| Plan changes                  | `tofu -chdir=tofu plan`                                                  |
| Format + validate             | `tofu -chdir=tofu fmt -recursive && tofu -chdir=tofu validate`           |
| Tear it all down              | `tofu -chdir=tofu destroy`                                               |

After running the kubeconfig fetch, use the cluster locally with:

```sh
export KUBECONFIG="$PWD/kubeconfig.devbox"
kubectl get nodes
```

## Variables

Only the most relevant are listed; see `tofu/variables.tf` for the full list
with descriptions and validation rules.

| Name                       | Default                                   | Notes                                                  |
| -------------------------- | ----------------------------------------- | ------------------------------------------------------ |
| `region`                   | from `linode-cli`, else `eu-west`         |                                                        |
| `instance_type`            | from `linode-cli`, else `g6-standard-4`   | 4 vCPU / 8 GB recommended minimum for k3s + agents    |
| `image`                    | from `linode-cli`, else `linode/ubuntu24.04` | Ubuntu 24.04 LTS                                    |
| `username`                 | local `$USER` at apply time               | Non-root user; override via `TF_VAR_username`          |
| `instance_label`           | `<username>-dev-box`                      |                                                        |
| `hostname`                 | (instance label)                          |                                                        |
| `timezone`                 | `UTC`                                     |                                                        |
| `authorized_keys`          | `[]`                                      | Required for SSH access                                |
| `root_pass`                | (required)                                | API requires it; SSH key auth is used in practice      |
| `create_firewall`          | `true`                                    |                                                        |
| `allowed_ssh_cidrs_ipv4/6` | open                                      | Restrict to your own IPs in production                 |
| `expose_web`               | `false`                                   | Open inbound 80/443                                    |
| `expose_k3s_api`           | `false`                                   | Open inbound 6443; requires CIDR allow-lists           |
| `install_docker`           | `true`                                    |                                                        |
| `install_k3s`              | `true`                                    |                                                        |
| `k3s_disable_components`   | `["traefik","servicelb"]`                 |                                                        |
| `install_languages`        | `["go","node","python","rust"]`           |                                                        |
| `install_claude_code`      | `true`                                    |                                                        |
| `install_opencode`         | `true`                                    |                                                        |
| `install_vscode_tunnel`    | `true`                                    | Manual `code tunnel` login on first boot               |
| `vscode_tunnel_name`       | (hostname)                                |                                                        |

## Security notes

- **No inbound web ports by default.** SSH (22) is the only port open out of
  the box. VSCode access uses Microsoft's outbound tunnel, so neither 80/443
  nor 6443 need to be exposed for the editor or for kubectl (use the
  `kubeconfig_fetch_command` output instead).
- **Restrict SSH** to your own networks via `allowed_ssh_cidrs_ipv4/6`.
- **Root login disabled** after cloud-init runs.
- **API token** lives only in `LINODE_TOKEN`. Scope it to Linodes RW +
  Firewalls RW.
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

Add ~$2/mo per plan if `backups_enabled = true`. Egress overages apply for
heavy demo traffic.

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
    │       ├── 10-base.sh
    │       ├── 20-docker.sh
    │       ├── 30-k3s.sh
    │       ├── 40-kube-tools.sh
    │       ├── 50-langs.sh
    │       ├── 60-agents.sh
    │       └── 70-vscode-tunnel.sh
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

Verify in the Linode console that no orphaned resources remain.

## Contributing

PRs welcome. Before opening one:

```sh
tofu -chdir=tofu fmt -recursive
tofu -chdir=tofu init -backend=false
tofu -chdir=tofu validate
```

## License

[MIT](LICENSE).
