# akamai-dev-box

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Validate](https://github.com/idvoretskyi/akamai-dev-box/actions/workflows/validate.yml/badge.svg)](https://github.com/idvoretskyi/akamai-dev-box/actions/workflows/validate.yml)
[![Trivy Security Scan](https://github.com/idvoretskyi/akamai-dev-box/actions/workflows/trivy.yml/badge.svg)](https://github.com/idvoretskyi/akamai-dev-box/actions/workflows/trivy.yml)

OpenTofu config for a Nanode-optimized Debian 13 dev box on [Akamai Cloud](https://www.linode.com/) (formerly Linode).

Deployed on a **Nanode 1** (1 vCPU / 1 GB RAM / 25 GB SSD) by default. Ships with zsh, tmux (Nord powerline), linode-cli, and a Mac-parity Homebrew toolchain — ready to use the moment cloud-init finishes (~10 min on Nanode).

## What's preinstalled

### System layer (apt)

| Tool | Notes |
|---|---|
| **zsh** | Default shell. oh-my-zsh with `agnoster` theme (powerline-style), `git`, `fzf`, `zoxide`, `zsh-autosuggestions`, and `zsh-syntax-highlighting` plugins. Requires a Nerd Font / Powerline-patched font in your terminal for glyphs to render correctly. |
| **tmux** | Nord powerline status bar. Mouse on, vi keys, base-index 1, auto-session naming. Auto-attaches on SSH login. |
| **linode-cli** | Installed via pipx (isolated venv). Pre-seeded with region/type/image when `linode_token` is set in tfvars. |
| **fzf** | Fuzzy finder with zsh key-bindings (Ctrl-R history, Ctrl-T files). |
| **zoxide** | Smarter `cd` — tracks frecency. Aliased as `z`. |
| **eza** | Modern `ls` replacement — `ll` alias with git status column. |
| **ncdu** | Disk usage analyser. |
| **git**, **curl**, **rsync**, **unzip** | Standard shell utilities. |
| **earlyoom** | Kills runaway processes before kernel OOM thrashes the box (critical on 1 GB). |

### Homebrew layer (Mac-parity userland)

Installed under `/home/linuxbrew/.linuxbrew` — identical `brew install` / `brew upgrade` workflow as macOS.

| Tool | Notes |
|---|---|
| **gh** | GitHub CLI. Run `gh auth login` on first SSH. |
| **bat** | `cat` with syntax highlighting. |
| **ripgrep** (`rg`) | Fast `grep` replacement. |
| **fd** | Fast `find` replacement. |
| **jq** | JSON processor. |
| **git-delta** | Pretty git diffs. |
| **htop** | Interactive process viewer. |
| **tree** | Directory tree display. |
| **neovim** | Modern Vim — no config shipped, bring your own. |
| **tldr** | Practical command examples. |
| **direnv** | Auto-loads `.envrc` per directory. Hook active in zsh. |
| **mise** | Language version manager (Node, Python, Go, Ruby, etc.). Hook active in zsh. |
| **zsh-completions** | Extra tab completions for brew, gh, docker, kubectl, etc. |
| **kubectl** | Kubernetes CLI. |
| **opentofu** | OpenTofu (Terraform-compatible IaC). |

## k3s

A super-tiny single-node [k3s](https://k3s.io/) cluster is installed on the box but **disabled by default** to preserve RAM on the Nanode (k3s idle ≈ 300 MB).

| Component | Status | Reason |
|---|---|---|
| coredns | enabled | required for cluster DNS |
| local-path-provisioner | enabled | PersistentVolume support |
| traefik | **disabled** | saves ~50 MB RAM |
| servicelb | **disabled** | pointless without external LB |
| metrics-server | **disabled** | saves ~30 MB RAM |
| network-policy | **disabled** | saves ~20 MB RAM |

### Usage

```sh
k3s-up          # start k3s (costs ~300 MB RAM while running)
kubectl get nodes
k get pods -A   # 'k' is aliased to kubectl

k3s-down        # stop k3s and reclaim RAM
```

`KUBECONFIG` is pre-set to `/etc/rancher/k3s/k3s.yaml` in `.zshrc`.

### RAM budget on Nanode

| State | RAM used (approx) |
|---|---|
| Debian + brew baseline | ~320 MB |
| + k3s running (no pods) | ~620 MB |
| + 1-2 tiny pods | ~700-750 MB |
| OOM risk threshold | ~900 MB |

earlyoom will protect the box at 5% free RAM (~50 MB), but keep workloads minimal.

## Prerequisites

- [OpenTofu](https://opentofu.org/) >= 1.6
- An [Akamai API token](https://cloud.linode.com/profile/tokens) with read/write on Linodes and Firewalls (exported as `LINODE_TOKEN`)
- An SSH public key (Ed25519 recommended)
- A [Nerd Font](https://www.nerdfonts.com/) or Powerline-patched font in your local terminal (for agnoster glyphs)
- Optional: `linode-cli` configured locally — region / instance type / image are inherited from it

## Quick start

```sh
export LINODE_TOKEN="your-token-here"
cp tofu/terraform.tfvars.example tofu/terraform.tfvars
$EDITOR tofu/terraform.tfvars                                # authorized_keys + root_pass

tofu -chdir=tofu init
tofu -chdir=tofu apply

# Wait for cloud-init to finish (~10 min on Nanode — brew formula install takes time)
eval "$(tofu -chdir=tofu output -raw wait_ready_command)"

# Install ~/.ssh/config block (idempotent)
eval "$(tofu -chdir=tofu output -raw ssh_config_install_command)"

ssh "$USER-dev-box"
# → drops straight into a tmux session with zsh + Homebrew on PATH
```

## Configuration

See `tofu/variables.tf` for the full list of inputs. Common ones:

- `region`, `instance_type`, `image` — inherited from `~/.config/linode-cli` if present; defaults to `linode/debian13`, `g6-nanode-1`, `gb-lon`
- `username` — defaults to local `$USER`; override via `TF_VAR_username`
- `authorized_keys`, `root_pass` — required
- `linode_token` — optional; when set, pre-seeds `linode-cli` on the box so it works without `linode-cli configure`
- `allowed_ssh_cidrs_ipv4` / `_ipv6` — restrict SSH to your own networks in production
- `extra_packages` — additional apt packages installed on first boot (keep minimal on Nanode)

## Supported images

| Image | Status |
|---|---|
| `linode/debian13` | Default |
| `linode/debian12` | Supported |
| `linode/ubuntu24.04` | Supported |
| `private/*` | Supported |

Set `image` in `terraform.tfvars` to switch.

## Homebrew

The box uses a two-layer package model mirroring macOS:

- **apt** — OS layer: kernel, sshd, systemd, security patching (`unattended-upgrades`), and system tools (fzf, zoxide, eza).
- **brew** — userland layer: everything you'd install on your Mac via `brew install`.

Install additional tools the same way as on your Mac:

```sh
brew install awscli kubectl helm k9s lazygit
```

`brew upgrade` updates all formulae. `brew update && brew upgrade` is the full refresh.

> **Note:** passwordless sudo is enabled for the `sudo` group. The user account is the only non-root user on the box, so this is equivalent to user-scoped NOPASSWD. SSH key auth is required (password auth is disabled). Restrict `allowed_ssh_cidrs_ipv4` to your own networks for additional hardening.

## Nanode considerations

This config is specifically tuned for the Nanode 1 plan (1 GB RAM):

- **4 GB swapfile** created before apt runs — prevents OOM during cloud-init and Homebrew bootstrap (~400 MB peak during portable-ruby install)
- **earlyoom** kills runaway processes at 5% free RAM / 10% free swap before the kernel thrashes
- **vm.swappiness=10** — keeps hot data in RAM; swap is a last resort
- **No install-recommends** — apt skips optional dependencies system-wide
- **Masked services** — rsyslog, multipathd, ModemManager, and systemd-networkd-wait-online disabled at first boot to reduce idle RAM
- **Journald capped** at 200 MB (persistent, compressed, no syslog forwarding)
- **tmux history-limit 5000** per pane — avoids silent RAM growth in long-running sessions
- Homebrew brew formula installs run sequentially with fail-open handling — if a formula fails on a transient mirror error, it is logged and skipped; re-run `brew install <formula>` after SSH in

**Expected idle RAM on Debian 13 + brew:** ~200–230 MB (vs ~335 MB on Ubuntu 24.04 — measured before migration).

## Scaling up

Set `instance_type` in `terraform.tfvars` to move to a larger plan:

```hcl
instance_type = "g6-standard-1"   # 1 vCPU / 2 GB / 50 GB
instance_type = "g6-standard-2"   # 2 vCPU / 4 GB / 80 GB
instance_type = "g6-standard-4"   # 4 vCPU / 8 GB / 160 GB
```

All Nanode optimizations (earlyoom, sysctl tuning, etc.) remain active and are beneficial on larger plans too.

## Tear down

```sh
tofu -chdir=tofu destroy
eval "$(tofu -chdir=tofu output -raw ssh_config_remove_command)"
```

## License

[MIT](LICENSE).
