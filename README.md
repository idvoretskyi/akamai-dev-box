# akamai-dev-box

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Validate](https://github.com/idvoretskyi/akamai-dev-box/actions/workflows/validate.yml/badge.svg)](https://github.com/idvoretskyi/akamai-dev-box/actions/workflows/validate.yml)
[![Trivy Security Scan](https://github.com/idvoretskyi/akamai-dev-box/actions/workflows/trivy.yml/badge.svg)](https://github.com/idvoretskyi/akamai-dev-box/actions/workflows/trivy.yml)

OpenTofu configuration for a personal, always-on Ubuntu 26.04 LTS dev box on [Akamai Cloud](https://www.linode.com/), dedicated to running hosted coding agents — opencode, Claude Code, Codex, and GitHub Copilot. Baseline: **g8-dedicated-16-4** (4 dedicated Zen 5 vCPUs / 16 GiB RAM / 160 GB disk, **$0.21/hour, no monthly cap, ≈$151–156/month**). Explicit variables override local Linode CLI defaults, which override built-in fallbacks; the example pins the baseline plan.

Connect through Termius or another SSH client, keep agents in tmux, and use the box for builds, containers, small CPU PyTorch experiments, and small local CPU LLMs. GPU training and Kubeflow execution belong to the separate [akamai-lke-gpu-cluster](https://github.com/idvoretskyi/akamai-lke-gpu-cluster) lab. This repo does not install Kubeflow or CUDA on the dev box.

Paid backups are disabled. Pricing is the London base rate, excluding taxes, additional services, and usage charges. Configuration changes alone do not resize an existing instance.

> **Network transfer:** G8 Dedicated plans carry no bundled outbound transfer allowance and are billed for all outbound traffic at usage-based rates ($0.005/GiB in `gb-lon`), regardless of the account's global transfer pool. A coding-agent workload's outbound (mostly API request bodies, not responses) typically runs single-digit GiB/month — cents. Check current usage with `linode-cli linodes transfer-view <linode-id>`. Break-even vs. the previous `g7-dedicated-16-8` baseline (6 TB bundled, $173/month cap) is around 4 TiB/month of outbound. If a future workload (e.g. an LKE cluster running Ollama) talks to this box, place that cluster in `gb-lon` and use a VPC or IPv6 address — same-datacenter private traffic is unmetered.

## What's included

**Shell:** zsh + oh-my-zsh, tmux, vim, and git config bootstrapped from [idvoretskyi/dotfiles](https://github.com/idvoretskyi/dotfiles) (override via `dotfiles_repo`). Devbox-specific extras land in `~/.zshrc.local` / `~/.gitconfig.local` — the dotfiles' own extension points. Plus: fzf, zoxide, eza, bat, ripgrep, fd, jq, git-delta, htop, ncdu, tldr (tealdeer), direnv, tree.

**Dev CLIs:** gh, VS Code (`code tunnel`), Claude Code, opencode, mise, kubectl, opentofu, linode-cli. Codex and GitHub Copilot are used through their own login (editor extension / `gh copilot`) — install and authenticate them yourself on first login.

**Containers:** Docker CE (+ buildx, compose) enables per-project [devcontainers](https://containers.dev/). Local k3s is installed without starting or enabling its service; use `k3s-up`, `k3s-kubectl`, and `k3s-down` explicitly.

**System:** zram (RAM/2, zstd), earlyoom.

## Fresh deployment

Only use this procedure to create a new instance. For the existing dev box, follow [Resize an existing instance](#resize-an-existing-instance). A clone does not include deployment state or secret inputs.

```sh
export LINODE_TOKEN="your-token-here"
cp tofu/terraform.tfvars.example tofu/terraform.tfvars
$EDITOR tofu/terraform.tfvars   # set authorized_keys + root_pass

tofu -chdir=tofu init -lockfile=readonly
tofu -chdir=tofu plan -out=create.tfplan
# Review the proposed resources and cost before applying.
tofu -chdir=tofu apply create.tfplan
eval "$(tofu -chdir=tofu output -raw wait_ready_command)"
eval "$(tofu -chdir=tofu output -raw ssh_config_install_command)"
ssh "$USER-dev-box"
# authenticate on first login: claude | opencode | code tunnel | gh auth login
```

## Configuration

Key variables (`tofu/variables.tf`):

| Variable | Default | Notes |
|---|---|---|
| `region` / `instance_type` / `image` | from `~/.config/linode-cli` (keys: `region`, `type`, `image`) | fallback: `gb-lon` / `g8-dedicated-16-4` / `linode/ubuntu26.04`; example pins the plan |
| `authorized_keys`, `root_pass` | — | required |
| `dotfiles_repo` | [idvoretskyi/dotfiles](https://github.com/idvoretskyi/dotfiles) | cloned to `~/.dotfiles`, installed unattended; `""` skips |
| `git_user_name` / `git_user_email` | — | optional; written to `~/.gitconfig.local` on the box |
| `linode_token` | unset | optional provider token; otherwise use `LINODE_TOKEN`; CLI seeding also requires `seed_linode_cli = true` |
| `backups_enabled` | `false` | paid backups are not part of this baseline |
| `deployment_user_data_base64` | `null` (unset) | sensitive; pins the exact original `metadata.user_data` for an existing-instance resize — see [Resize an existing instance](#resize-an-existing-instance); never set in `terraform.tfvars.example` |
| `allowed_ssh_cidrs_ipv4/6` | `0.0.0.0/0` / `::/0` | restrict where practical without locking out remote access |
| `extra_packages` | `[]` | additional apt packages |

Supported images: any `linode/ubuntu<NN>.<NN>` slug (e.g. `linode/ubuntu26.04`, default) or `private/*`. Pin `region`, `username`, and `instance_label` for repeatable deployments instead of inheriting another operator's environment. State defaults to the local backend in `tofu/backend.tf`; the instance keeps `resize_disk = false` (plan changes preserve existing disks) and `prevent_destroy = true` (a plan that would replace or destroy it fails instead — see [Intentional replacement](#intentional-replacement)).

## Scaling

```
g6-standard-6       6 vCPU (shared)  / 16 GB / 320 GB — $96/mo   (budget alternative; bundled 6 TB transfer)
g8-dedicated-8-4    4 vCPU (Zen 5)   /  8 GB /  80 GB — ~$102/mo (0.14/hr)
g8-dedicated-16-4   4 vCPU (Zen 5)   / 16 GB / 160 GB — ~$153/mo (0.21/hr, baseline)
g8-dedicated-16-8   8 vCPU (Zen 5)   / 16 GB / 160 GB — ~$197/mo (0.27/hr; more parallel throughput, e.g. -j8 builds or CPU LLM prompt processing)
g8-dedicated-32-8   8 vCPU (Zen 5)   / 32 GB / 320 GB — ~$307/mo (0.42/hr)
g8-dedicated-32-16 16 vCPU (Zen 5)   / 32 GB / 320 GB — ~$394/mo (0.54/hr; 30B-class local MoE models)
```

Plan sizes use Linode's GB labels; RAM and disk allowances correspond to GiB. Prices are the London (`gb-lon`) hourly rate × ~730 hours; `id-cgk` and `br-gru` carry a regional uplift (roughly +20% and +40%). Since 2026-07-01, G8 Dedicated plans (like GPU Linodes) are billed hourly with **no monthly cap** — the figures above are indicative, not a hard ceiling; see [Understanding how billing works](https://techdocs.akamai.com/cloud-computing/docs/understanding-how-billing-works). `g6-standard-6` is a shared-CPU alternative with identical RAM and disk, useful if dedicated CPU isn't required, and it still carries a bundled transfer allowance unlike the G8 plans above. The previous baseline was `g7-dedicated-16-8` (8 dedicated Zen 3 vCPUs / 16 GiB RAM / 320 GiB disk, $173/month cap, 6 TB bundled transfer) — its larger disk allowance and parallel throughput may still suit workloads that don't fit `g8-dedicated-16-8`.

## Resize an existing instance

1. Work from the machine that owns the deployment state (e.g. your MacBook) — never from the dev box being resized, and never from missing state.
2. Push every working repository and back up local-only data first; a resize reboots the box and SSH/tmux sessions do not survive.
3. **Downsizing:** the target plan's disk allowance must already fit the instance's current disks (160 GB for `g8-dedicated-16-4`; the existing instance's disks already total 160 GB). Check with `linode-cli linodes disks-list <id>` or Cloud Manager; disk shrink is a separate, powered-off, manually approved step, never a side effect of this plan.
4. Read the exact `metadata.user_data` out of verified state and write it directly to a private, ignored `*.auto.tfvars.json` file — do not print it to the terminal, since it may embed the Linode API token when `seed_linode_cli` was enabled:
   ```sh
   (umask 077 && tofu -chdir=tofu show -json | jq \
     '{deployment_user_data_base64: (.values.root_module.resources[]
       | select(.address=="linode_instance.dev_box") | .values.metadata[0].user_data)}' \
     > tofu/zz-existing-deployment.auto.tfvars.json)
   ```
   `umask 077` keeps the file `0600` as it's created; never `cat`, log, or commit it. Any other diff in the rendered cloud-init forces replacement (`user_data` is `ForceNew`), which `prevent_destroy` blocks outright.
5. Change only `instance_type`. Generate a saved plan and confirm it shows a single in-place `type` update — no replacement, disk, or firewall changes.
6. Apply in a maintenance window (cold migration = reboot). Reconnect and verify `nproc`, `free -h`, `df -h`, `swapon --show`, and `systemctl --failed` match the target plan; zram adjusts to RAM/2 on reboot.

Resizing more than once within a billing month produces a separate prorated invoice line item per plan used (each billed only for its active hours; no double-charging) — expect a noisier invoice, not an inflated one.

If startup fails, use Lish to investigate rather than rebuilding immediately.

### Intentional replacement

If reconciliation isn't feasible and a plan requires replacing the instance: remove (or comment out) `prevent_destroy = true` in `tofu/main.tf` as a deliberate, reviewed change, review the inputs as for a [fresh deployment](#fresh-deployment) (leave `deployment_user_data_base64` unset), confirm the plan shows only an expected `-/+` replacement (plus the firewall reattaching to the new instance ID), apply, then update SSH config (`ssh_config_install_command`/`ssh_config_remove_command` outputs) and reauthenticate agents on first login. Restore `prevent_destroy = true` afterward so later plans stay guarded by default. Never commit plaintext state, tfvars, tokens, or kubeconfigs.

## Remote coding and ML

| On this dev box | On the separate LKE cluster |
|---|---|
| SSH, tmux, coding agents, Git worktrees | Kubeflow and GPU platform services |
| Small CPU PyTorch experiments and unit tests | GPU training, inference, and pipeline execution |
| Pipeline authoring/compilation and container builds | Scheduled workload pods and persistent lab volumes |
| Kubernetes clients and dashboard tunnels | Cluster monitoring and GPU management |

Use separate worktrees and distinct Compose project names, ports, and volumes for concurrent projects. Worktrees are not security boundaries. Scope agent credentials; Docker-group membership and sudo provide privileged host access.

If a future LKE cluster runs Ollama or another service this box talks to, place that cluster in `gb-lon` and connect over a VPC or IPv6 address rather than public IPv4 — same-datacenter private traffic doesn't count against either side's network transfer.

### Local LLM inference (optional)

Hosted coding agents are the primary tools; a small local model works for offline or privacy-sensitive moments. Nothing is installed by cloud-init. Models that fit comfortably in 16 GiB (Q4_K_M):

| Model | Tag | Size |
|---|---|---|
| Gemma 4 12B | `gemma4:12b` | 7.6 GB |
| Ornith 1.5 9B | `ornith-1.5:9b` | 6.6 GB |
| Granite 4.2 8B | `granite4.2:8b` | 5.3 GB |

```sh
curl -fsSL https://ollama.com/install.sh | sh   # listens on 127.0.0.1:11434 by default
ollama run gemma4:12b
ollama run ornith-1.5:9b
ollama run granite4.2:8b
```

Keep it on localhost (reach it via `ssh -L 11434:127.0.0.1:11434 $USER-dev-box`), don't run it alongside heavy builds, and expect 27B+ models to need the 32 GiB tier (see [Scaling](#scaling)).

### Python and PyTorch

Use a project-local environment with a Python version supported by the chosen PyTorch release, managed via mise rather than replacing Ubuntu's system Python:

```sh
python -m venv .venv
. .venv/bin/activate
python -m pip install torch --index-url https://download.pytorch.org/whl/cpu
python -c 'import torch; print(torch.__version__); print("CUDA available:", torch.cuda.is_available())'
```

This is a CPU-only smoke setup, not a locked project spec. Pin dependencies, bound thread/DataLoader worker counts, and keep datasets and checkpoints on disk-backed paths, not `/tmp` when tmpfs-mounted.

### Remote Kubernetes access

The [LKE repository](https://github.com/idvoretskyi/akamai-lke-gpu-cluster) owns cluster provisioning and kubeconfig setup. Obtain credentials securely and keep them outside Git.

```sh
kubectl config get-contexts
kubectl --context LAB_CONTEXT get nodes
kubectl --context LAB_CONTEXT --namespace YOUR_NAMESPACE get pods
kubectl --context LAB_CONTEXT --namespace NAMESPACE port-forward --address 127.0.0.1 svc/SERVICE 8080:SERVICE_PORT
```

Check `kubectl version --client` against the server version and pin a compatible client with mise if needed. For dashboards, forward the local port through your SSH client to `127.0.0.1:8080` — never bind to `0.0.0.0` or expose notebooks through public firewall rules.

### Optional local k3s

Use `k3s-up` and `k3s-kubectl` for disposable local Kubernetes experiments; keep the full Kubeflow platform on LKE. `k3s-down` (the installed `k3s-killall.sh`) stops local containers and resets local networking without deleting cluster data — it does not touch the remote LKE cluster and is not `k3s-uninstall.sh`.

## Development checks

See [AGENTS.md](AGENTS.md) for repository layout and operational safeguards.

```sh
tofu -chdir=tofu fmt -check -recursive -diff
tofu -chdir=tofu init -backend=false -lockfile=readonly
tofu -chdir=tofu validate
git diff --check
```

These checks do not create or resize infrastructure.

## Troubleshooting

```sh
eval "$(tofu -chdir=tofu output -raw first_boot_log_command)"
# /var/lib/devbox-init.done → success  |  .failed → check the log
```

## Tear down

`linode_instance.dev_box` has `prevent_destroy = true` (see [Configuration](#configuration)); `tofu destroy` fails against it by design. Remove or comment out that guard as a deliberate, reviewed change before tearing down:

```sh
tofu -chdir=tofu destroy && eval "$(tofu -chdir=tofu output -raw ssh_config_remove_command)"
```

## License

[MIT](LICENSE).
