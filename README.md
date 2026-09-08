# akamai-dev-box

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Validate](https://github.com/idvoretskyi/akamai-dev-box/actions/workflows/validate.yml/badge.svg)](https://github.com/idvoretskyi/akamai-dev-box/actions/workflows/validate.yml)
[![Trivy Security Scan](https://github.com/idvoretskyi/akamai-dev-box/actions/workflows/trivy.yml/badge.svg)](https://github.com/idvoretskyi/akamai-dev-box/actions/workflows/trivy.yml)

OpenTofu configuration for an always-on Ubuntu 26.04 LTS development workstation on [Akamai Cloud](https://www.linode.com/). Baseline: **g6-standard-6** (6 shared vCPUs / 16 GiB RAM / 320 GiB disk allowance, **$96/month**). Explicit variables override local Linode CLI defaults, which override built-in fallbacks; the example pins the baseline plan.

Connect through Termius or another SSH client, keep coding agents in tmux, and use the box for builds, containers, and small CPU PyTorch experiments. GPU training and Kubeflow execution belong to the separate [akamai-lke-gpu-cluster](https://github.com/idvoretskyi/akamai-lke-gpu-cluster) lab. This repo does not install Kubeflow or CUDA on the dev box.

Paid backups are disabled. Pricing is the London base rate checked September 8, 2026, excluding taxes, additional services, and usage charges. Configuration changes alone do not resize an existing instance.

## What's included

**Shell:** zsh + oh-my-zsh, tmux, vim, and git config bootstrapped from [idvoretskyi/dotfiles](https://github.com/idvoretskyi/dotfiles) (override via `dotfiles_repo`). Devbox-specific extras land in `~/.zshrc.local` / `~/.gitconfig.local` — the dotfiles' own extension points. Plus: fzf, zoxide, eza, bat, ripgrep, fd, jq, git-delta, htop, ncdu, tldr (tealdeer), direnv, tree.

**Dev CLIs:** gh, VS Code (`code tunnel`), Claude Code, opencode, mise, kubectl, opentofu, linode-cli.

**Containers:** Docker CE (+ buildx, compose) enables per-project [devcontainers](https://containers.dev/). Local k3s is installed without starting or enabling its service; use `k3s-up`, `k3s-kubectl`, and `k3s-down` explicitly. Normal `kubectl` uses the standard kubeconfig lookup, not a forced local-cluster configuration.

**System:** zram (RAM/2, zstd), earlyoom.

## Fresh deployment

Only use this procedure to create a new instance. For the existing dev box, follow [Upgrade an existing instance](#upgrade-an-existing-instance). A clone does not include deployment state or secret inputs.

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
| `region` / `instance_type` / `image` | from `~/.config/linode-cli` (keys: `region`, `type`, `image`) | fallback: `gb-lon` / `g6-standard-6` / `linode/ubuntu26.04`; example pins the plan |
| `authorized_keys`, `root_pass` | — | required |
| `dotfiles_repo` | [idvoretskyi/dotfiles](https://github.com/idvoretskyi/dotfiles) | cloned to `~/.dotfiles`, installed unattended; `""` skips |
| `git_user_name` / `git_user_email` | — | optional; written to `~/.gitconfig.local` on the box |
| `linode_token` | unset | optional provider token; otherwise use `LINODE_TOKEN`; CLI seeding also requires `seed_linode_cli = true` |
| `backups_enabled` | `false` | paid backups are not part of this baseline |
| `allowed_ssh_cidrs_ipv4/6` | `0.0.0.0/0` / `::/0` | restrict where practical without locking out remote access |
| `extra_packages` | `[]` | additional apt packages |

Supported images: any `linode/ubuntu<NN>.<NN>` slug (e.g. `linode/ubuntu26.04`, default) or `private/*`. Note: an `image` key in `~/.config/linode-cli` overrides the built-in fallback — pin `image` in `terraform.tfvars` to be explicit.

For repeatable deployments, also pin `region`, `username`, and `instance_label` instead of inheriting another operator's environment. The instance resource explicitly uses cold migration and `resize_disk = false`: plan changes preserve existing disk sizes. A fresh deployment still receives its plan's initial disk allocation.

## Scaling

```
g6-standard-2   2 vCPU /  4 GB /  80 GB — $24/mo
g6-standard-4   4 vCPU /  8 GB / 160 GB — $48/mo
g6-standard-6   6 vCPU / 16 GB / 320 GB — $96/mo  (baseline)
g6-standard-8   8 vCPU / 32 GB / 640 GB — $192/mo
g6-dedicated-2  2 vCPU /  4 GB /  80 GB — $36/mo  (dedicated CPU)
g6-dedicated-4  4 vCPU /  8 GB / 160 GB — $72/mo  (dedicated CPU)
g6-dedicated-8  8 vCPU / 16 GB / 320 GB — $144/mo (dedicated CPU)
```

Plan sizes above use Linode's GB labels; RAM and disk allowances correspond to GiB. Shared CPU is a good starting point for bursty development. Consider dedicated CPU for sustained builds, or more RAM for frequent concurrent agents, browsers, and databases. Hosted AI model inference does not run on this VM.

## Upgrade an existing instance

1. Locate the original deployment state and inputs. With this repo's default local backend, state normally lives at `tofu/terraform.tfstate`. Confirm `linode_instance.dev_box` maps to the intended existing instance. If state is missing, stop: recover it or perform a separately reviewed import of the instance and firewall, reconciling disks and boot configuration. Never apply from empty state to upgrade a VM.
2. Work from another machine with access to Cloud Manager and Lish. Preserve state and deployment inputs securely. Use the locked providers and review a baseline plan before changing the deployment's inputs. Do not change image, SSH keys, identity, region, or firewall as part of the resize.
3. Check each working repository for uncommitted work and unpushed commits. Preserve required agent state, local databases, and other local-only data separately. No paid backups are required by this workflow: accept that anything not preserved may be lost and a failure may require rebuilding. GitHub only protects data actually pushed there.
4. Explicitly set `instance_type = "g6-standard-6"` in the existing deployment inputs; leave `backups_enabled = false`. Keep automatic disk expansion disabled. The upgrade provides the new disk allowance without immediately growing the root filesystem.
5. Generate a saved plan and require an in-place update, with no unintended creation, deletion, replacement, disk, or firewall changes. Review metadata changes carefully: this branch also changes cloud-init templates. Do not assume a full-repository apply is only a CPU/RAM resize, and do not use broad `ignore_changes` to conceal differences.
6. In a maintenance window, stop agents and write-heavy services cleanly, then apply the reviewed plan externally. Cold migration shuts down the VM; SSH disconnects and tmux processes do not survive. Monitor the provider event through completion. Do not assume a fixed migration duration.
7. Reconnect and verify `nproc`, `free -h`, `lsblk`, `df -h`, `swapon --show`, and `systemctl --failed`. Expect 6 CPUs, roughly 16 GiB usable RAM, and unchanged disk sizes. Zram is configured as RAM/2 and should adjust on reboot. Test a build and remote-cluster access, then confirm a subsequent OpenTofu plan has no unexpected drift.

If startup fails, use Lish to investigate rather than rebuilding immediately. Keeping disk allocation unchanged simplifies a later downgrade, but another resize still requires downtime and availability. Expand storage only as a separately reviewed operation when needed.

State and plan files can contain passwords and user data. Never commit plaintext state, secret tfvars, tokens, or kubeconfigs, even to private GitHub repositories. If encrypted recovery artifacts are stored in a private repo, retain the decryption key elsewhere. GitHub repositories are not live OpenTofu backends with state locking.

### Existing-host shell migration

Cloud-init is a first-boot mechanism, not ongoing configuration management. Resizing does not install these repository changes onto the host. Do not rerun the full bootstrap or reset cloud-init to apply a shell fix.

On hosts created with the older template, edit only the k3s section in `~/.zshrc.local`: remove `export KUBECONFIG=/etc/rancher/k3s/k3s.yaml` and replace the local aliases with:

```sh
alias k3s-kubectl='sudo k3s kubectl --kubeconfig=/etc/rancher/k3s/k3s.yaml'
alias k3s-up='sudo systemctl start k3s && echo "k3s started; run: k3s-kubectl get nodes"'
alias k3s-down='sudo /usr/local/bin/k3s-killall.sh'
```

Unset `KUBECONFIG` in existing shells only if it still contains that old local path, then reload the edited shell configuration. Existing tmux sessions may also retain the old environment. Keep any intentional custom kubeconfig setup. Change the existing k3s `--write-kubeconfig-mode` setting from `0644` to `0600` and restrict the file's permissions during a separately scheduled local-k3s maintenance step; the new template uses root-only credentials accessed via sudo.

## Remote coding and ML

| On this dev box | On the separate LKE cluster |
|---|---|
| SSH, tmux, coding agents, Git worktrees | Kubeflow and GPU platform services |
| Small CPU PyTorch experiments and unit tests | GPU training, inference, and pipeline execution |
| Pipeline authoring/compilation and container builds | Scheduled workload pods and persistent lab volumes |
| Kubernetes clients and dashboard tunnels | Cluster monitoring and GPU management |

Use separate worktrees and distinct Compose project names, ports, and volumes for concurrent projects. Worktrees are not security boundaries. Scope agent credentials; Docker-group membership and sudo provide privileged host access. Limit build/test concurrency so SSH and interactive agents remain responsive.

### Python and PyTorch

Use a project-local environment with a Python version supported by the chosen PyTorch release. Manage Python via mise rather than replacing Ubuntu's system Python. In that project, using the selected interpreter:

```sh
python -m venv .venv
. .venv/bin/activate
python -m pip install torch --index-url https://download.pytorch.org/whl/cpu
python -c 'import torch; print(torch.__version__); print("CUDA available:", torch.cuda.is_available())'
```

This is a CPU-only smoke setup, not a locked project specification. Pin dependencies and record the CPU package source in the project's lock/config files. Install the appropriate Kubeflow SDK in that environment when needed; match its version to the remote platform. CUDA dependencies belong in remote GPU workload images.

Bound PyTorch thread counts and DataLoader workers; start with a single small experiment rather than saturating all CPUs alongside builds. Store datasets, checkpoints, and artifacts on disk-backed paths, not `/tmp` when it is mounted as tmpfs. Cache only what can be regenerated without recovery.

### Remote Kubernetes access

The [LKE repository](https://github.com/idvoretskyi/akamai-lke-gpu-cluster) owns cluster provisioning and kubeconfig setup. Obtain credentials securely and keep them outside Git. Do not run that repository's `apply` merely to connect to an existing cluster.

```sh
kubectl config get-contexts
# Replace LAB_CONTEXT with the intended context; do not switch it implicitly.
kubectl --context LAB_CONTEXT get nodes
kubectl --context LAB_CONTEXT --namespace YOUR_NAMESPACE get pods
```

Check `kubectl version --client` against the actual API-server version; kubectl should be within one minor version of the server. Bootstrap currently installs the latest stable client, which is not a compatibility guarantee for an older cluster. Pin a compatible client with mise when needed. The cluster repo also requires standalone `kustomize` for its Kubeflow installation workflow; it is not installed by this bootstrap. Install the version required by the selected Kubeflow manifests when working on that repo. `kubectl kustomize` is not a replacement for scripts invoking `kustomize` directly.

For dashboards, run a localhost-bound port forward on the dev box (replace all placeholders):

```sh
kubectl --context LAB_CONTEXT --namespace NAMESPACE port-forward --address 127.0.0.1 svc/SERVICE 8080:SERVICE_PORT
```

In Termius, configure local forwarding from your client port 8080 to `127.0.0.1:8080` through the dev-box SSH connection. Open `http://127.0.0.1:8080` on that client, retaining the service's authentication and using HTTPS if required. Do not bind the remote forward to `0.0.0.0` or expose notebooks through public firewall rules. A forward in tmux survives SSH loss, but the client tunnel must reconnect and neither survives a VM reboot automatically.

### Optional local k3s

Use `k3s-up` and `k3s-kubectl` for disposable local Kubernetes experiments. Keep the full Kubeflow platform on LKE. Apply pod requests/limits and restrict parallel jobs on this shared workstation.

`k3s-down` invokes the installed `k3s-killall.sh`: it stops local k3s containers and resets local cluster networking without deleting cluster data. Stop important jobs gracefully first and verify local resources have been released. It does not shut down the remote LKE cluster. Never confuse it with `k3s-uninstall.sh`, which removes the local installation and data.

## Development checks

See [AGENTS.md](AGENTS.md) for repository layout and operational safeguards.

```sh
tofu -chdir=tofu fmt -check -recursive -diff
tofu -chdir=tofu init -backend=false -lockfile=readonly
tofu -chdir=tofu validate
git diff --check
```

These checks do not create or resize infrastructure. Validate rendered shell/YAML syntax when editing cloud-init; do not execute first-boot scripts on the development host.

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
