# akamai-dev-box

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Validate](https://github.com/idvoretskyi/akamai-dev-box/actions/workflows/validate.yml/badge.svg)](https://github.com/idvoretskyi/akamai-dev-box/actions/workflows/validate.yml)
[![Trivy Security Scan](https://github.com/idvoretskyi/akamai-dev-box/actions/workflows/trivy.yml/badge.svg)](https://github.com/idvoretskyi/akamai-dev-box/actions/workflows/trivy.yml)

OpenTofu configuration for an always-on Ubuntu 26.04 LTS development workstation on [Akamai Cloud](https://www.linode.com/). Baseline: **g7-dedicated-32-16** (16 dedicated vCPUs / 32 GiB RAM / 640 GiB disk allowance, **$346/month**). Explicit variables override local Linode CLI defaults, which override built-in fallbacks; the example pins the baseline plan.

Connect through Termius or another SSH client, keep coding agents in tmux, and use the box for builds, containers, small CPU PyTorch experiments, and occasional local CPU LLM inference (e.g. quantized Qwen 30B-class models) alongside hosted coding-agent subscriptions (Claude Code, Codex, Copilot). GPU training and Kubeflow execution belong to the separate [akamai-lke-gpu-cluster](https://github.com/idvoretskyi/akamai-lke-gpu-cluster) lab. This repo does not install Kubeflow or CUDA on the dev box.

Paid backups are disabled. Pricing is the London base rate checked September 14, 2026, excluding taxes, additional services, and usage charges. Configuration changes alone do not resize an existing instance.

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
| `region` / `instance_type` / `image` | from `~/.config/linode-cli` (keys: `region`, `type`, `image`) | fallback: `gb-lon` / `g7-dedicated-32-16` / `linode/ubuntu26.04`; example pins the plan |
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
g6-standard-8       8 vCPU (shared)  / 32 GB / 640 GB — $192/mo  (budget alternative, same RAM/disk)
g7-dedicated-4-2    2 vCPU (dedicated) /  4 GB /  80 GB —  $43/mo
g7-dedicated-8-4    4 vCPU (dedicated) /  8 GB / 160 GB —  $86/mo
g7-dedicated-16-8   8 vCPU (dedicated) / 16 GB / 320 GB — $173/mo (14B-class local models only)
g7-dedicated-32-16 16 vCPU (dedicated) / 32 GB / 640 GB — $346/mo (baseline)
g7-dedicated-64-32 32 vCPU (dedicated) / 64 GB / 1280 GB — $691/mo (Qwen3-Next 80B-class tier)
```

Plan sizes above use Linode's GB labels; RAM and disk allowances correspond to GiB. Prices are the London (`gb-lon`) base rate; `id-cgk` and `br-gru` carry a regional uplift (roughly +20% and +40%). Per [Akamai's compute-plan documentation](https://techdocs.akamai.com/cloud-computing/docs/how-to-choose-a-compute-instance-plan), G7 Dedicated plans run on Zen 3 cores with full physical cores reserved per Linode, eliminating shared-tenant CPU contention. `g6-standard-8` is a shared-CPU alternative with identical RAM and disk at a lower price, useful if dedicated CPU isn't required. 16 GiB plans cannot hold a 30B-class quantized model — see [Local LLM inference](#local-llm-inference-optional) for sizing. Hosted AI coding-agent subscriptions (Claude Code, Codex, Copilot) remain the primary tools; local inference on this VM is occasional/secondary.

## Upgrade an existing instance

1. Locate the original deployment state and inputs. With this repo's default local backend, state normally lives at `tofu/terraform.tfstate` **on the machine that owns the deployment** (e.g. your MacBook, not this dev box). Confirm `linode_instance.dev_box` maps to the intended existing instance. If state is missing, stop: recover it or perform a separately reviewed import of the instance and firewall, reconciling disks and boot configuration. Never apply from empty state to upgrade a VM.
2. Work from another machine with access to Cloud Manager and Lish — never from the dev box being resized. Preserve state and deployment inputs securely. Use the locked providers and review a baseline plan before changing the deployment's inputs. Do not change image, SSH keys, identity, region, or firewall as part of the resize.
3. Check each working repository for uncommitted work and unpushed commits. Preserve required agent state, local databases, and other local-only data separately. No paid backups are required by this workflow: accept that anything not preserved may be lost and a failure may require rebuilding. GitHub only protects data actually pushed there.
4. Explicitly set `instance_type = "g7-dedicated-32-16"` in the existing deployment inputs only — do not change any other variable. Leave `backups_enabled = false`. Keep automatic disk expansion disabled. Confirm `g7-dedicated-32-16` is actually orderable in the deployment's region before planning a G7 target. This is a cross-generation resize (e.g. from `g6-standard-4`); the new disk allowance is provided without immediately growing the root filesystem.
5. Generate a saved plan and require an in-place update only: **any planned change to `metadata.user_data` forces replacement**, not an in-place update — the locked `linode/linode` provider declares that field `ForceNew`, so a changed rendered payload destroys and recreates the instance (and its local disks) rather than updating it in place. If the plan shows a `metadata.user_data` diff, stop and reconcile it before applying. `local.cloud_init` in `tofu/locals.tf` is rendered from **every one of**: `username` (defaults to the local `$USER` running `tofu apply` when `var.username` is unset — pin `username` explicitly if you apply from a different machine or account than the original deployment), `hostname`, `timezone`, `authorized_keys`, `extra_packages`, `region`, `image`, `git_user_name`, `git_user_email`, `dotfiles_repo` (via the embedded first-boot script), plus `seed_linode_cli`/`linode_token`/`instance_type` when CLI seeding applies (see below) — pin all of these to their exact existing values before generating the plan; a change in any one of them changes `metadata.user_data` just as much as an intentional `instance_type` change would (cloud-init template edits from history, e.g. #21, also change this field and must not be applied to an existing instance this way). Confirm the plan shows only an in-place `type` update, with no unintended creation, deletion, replacement, disk, or firewall changes, before proceeding. Do not use broad `ignore_changes` to conceal a real difference instead of reconciling it.

   **Seeded deployments cannot use this in-place procedure.** When `seed_linode_cli = true` and `linode_token` is set, the rendered cloud-init embeds the resolved `instance_type` (see `tofu/cloud-init/main.yaml.tpl`). Changing the plan therefore changes `metadata.user_data` regardless of which other variables are pinned, and the plan will show a replacement. Pinning variables does not prevent this. If your existing deployment has `seed_linode_cli = true`, either accept the [intentional replacement](#intentional-replacement-seeded-or-otherwise-forced) below, or set `seed_linode_cli = false` in a separate, prior apply first (that alone still changes user data and is itself a replacement) so that a later plan-only resize has nothing left to seed.
6. In a maintenance window, stop agents and write-heavy services cleanly, then apply the reviewed plan externally. Cold migration shuts down the VM; SSH disconnects and tmux processes do not survive. Monitor the provider event through completion. Do not assume a fixed migration duration.
7. Reconnect and verify `nproc`, `free -h`, `lsblk`, `df -h`, `swapon --show`, and `systemctl --failed`. Expect 16 CPUs, roughly 32 GiB usable RAM, and unchanged disk sizes. Also inspect the new host's actual CPU with `lscpu | grep "Model name"` and `grep -o -E "avx2|avx512f|fma|f16c" /proc/cpuinfo | sort -u` — this is informational (record what you get; don't assume a specific generation or instruction set in advance, see [Scaling](#scaling)). Zram is configured as RAM/2 and should adjust on reboot. Test a build and remote-cluster access, then confirm a subsequent OpenTofu plan has no unexpected drift.

If startup fails, use Lish to investigate rather than rebuilding immediately. Keeping disk allocation unchanged simplifies a later downgrade, but another resize still requires downtime and availability. Expand storage only as a separately reviewed operation when needed.

### Intentional replacement (seeded or otherwise forced)

If the reviewed plan requires replacement — because CLI seeding is enabled, cloud-init templates changed, or another pinned input still differs — an in-place resize is not available; a rebuild is the accepted alternative:

1. Push every working repository first, including local branches and commits; separately back up any uncommitted files, local databases, credentials, and other host-local data you need. GitHub only preserves what has been pushed.
2. Preserve the original state and `terraform.tfvars` securely, then review the full set of proposed inputs as if for a [fresh deployment](#fresh-deployment): SSH keys, username, image, `dotfiles_repo`, and any other variables. A replacement creates a new instance with these inputs rather than reusing the old boot configuration.
3. Review the saved plan for an explicit `-/+` replacement of `linode_instance.dev_box`, with no unrelated resource creation or deletion. When `create_firewall = true`, expect an in-place update to `linode_firewall.dev_box_fw[0].linodes` to attach the existing firewall to the replacement instance's new ID (see `tofu/main.tf`). This attachment update is expected; changes to firewall rules, policies, or allowed CIDRs must be intentional and separately reviewed.
4. Apply the reviewed plan. The new instance receives the plan's initial disk allocation (not the old instance's disk sizes) and reruns first-boot bootstrap; local files on the old instance's disks are not carried over.
5. Update your SSH config with the new IP (`ssh_config_install_command`/`ssh_config_remove_command` outputs) and reauthenticate `claude` / `opencode` / `code tunnel` / `gh auth login` on first login, same as [Fresh deployment](#fresh-deployment).

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
| Occasional local CPU LLM inference (quantized Qwen/GLM/Gemma via llama.cpp or Ollama) | — |

Use separate worktrees and distinct Compose project names, ports, and volumes for concurrent projects. Worktrees are not security boundaries. Scope agent credentials; Docker-group membership and sudo provide privileged host access. Limit build/test concurrency so SSH and interactive agents remain responsive.

### Local LLM inference (optional)

Hosted coding-agent subscriptions (Claude Code, Codex, Copilot) remain the primary tools. The baseline's 32 GiB RAM also fits a secondary, occasional local model for offline use, privacy-sensitive code, or quota-exhausted moments — no cloud-init installation is included; install a runtime yourself in a project-local or user-scoped location.

**Memory budget:** zram is compressed swap, not extra RAM — do not count it toward model weights. Sizes below are on-disk/download sizes for weights only; actual runtime usage is higher once the KV cache, context, and (for vision models) image encoders are loaded. Start with one loaded model, one request at a time, and a conservative initial context (roughly 4K-8K tokens); increase context only after measuring actual memory usage with `free -h`, and leave headroom for Docker, agents, and the OS.

**Models that fit at 32 GiB (Q4_K_M unless noted):**

| Model | Architecture | Approx. weight size | Notes |
|---|---|---|---|
| Qwen3-30B-A3B / Qwen3-Coder-30B-A3B | MoE, ~3B active | ~18 GB | fast (bandwidth-bound, not core-bound); good default for interactive agentic use |
| Qwen3.6-35B-A3B | MoE, ~3B active | ~19 GB | newer agentic-tuned MoE successor |
| GLM-4.7-Flash (30B-A3B) | MoE, ~3B active | ~19 GB | strong coding-focused MoE alternative |
| Nemotron 3.5 Lightning (30B-A3B) | MoE, ~3B active | ~18 GB | tuned for always-on agent workloads |
| Qwen3.8-27B / Qwen3.6-27B | dense | ~18 GB | vision + tools + thinking; higher quality, much slower on CPU — treat generation speed as unverified until measured on this hardware |
| Gemma 4 26B (A4B) | MoE, ~4B active | ~19 GB | text + image, tools + thinking |
| Gemma 4 31B | dense | ~20 GB | text + image, tools + thinking; no audio support in either Gemma 4 26B or 31B |

Dense 30B+ models (e.g. plain Qwen 32B) do not fit meaningfully better than the MoE options above and are markedly slower; prefer an MoE model for anything interactive. 16 GiB-class plans (see [Scaling](#scaling)) cannot hold any of the above — they're limited to ~14B dense models (Qwen3-14B, Qwen2.5-Coder-14B).

**Running it:**

- Build or install [llama.cpp](https://github.com/ggml-org/llama.cpp) (`llama-server`) or [Ollama](https://ollama.com/) under your own user account; keep model files on disk-backed paths (the 640 GiB allowance), never under `/tmp` when it's tmpfs-mounted.
- Bind the inference server to `127.0.0.1` only and reach it via an SSH tunnel from your client, the same pattern used for [dashboards](#remote-kubernetes-access) below — never expose it through the firewall.
- Bound thread counts explicitly (e.g. `-t 12` on the 16-dedicated-vCPU baseline) and avoid running inference concurrently with heavy builds or PyTorch jobs; dedicated cores remove shared-tenant contention but still share this single box's memory bandwidth.
- Check the actual CPU features with `grep -o -E "avx2|avx512f|fma|f16c" /proc/cpuinfo | sort -u` before assuming any instruction-set speedup. G7 Dedicated runs Zen 3 per Akamai's plan documentation; any instruction-set or performance benefit over the previous host still needs to be measured. Token-generation speed for MoE models is dominated by memory bandwidth regardless of CPU generation. Benchmark both prompt-processing and token-generation throughput on the actual host before relying on it for a workflow.

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
