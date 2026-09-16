# Agent Guide

## Purpose

This repository provisions a personal, always-on Ubuntu development
workstation on Akamai Cloud dedicated to running hosted coding agents
(opencode, Claude Code, Codex, GitHub Copilot). The baseline is
`g8-dedicated-16-4` (4 dedicated Zen 5 vCPUs, 16 GiB RAM, 164 GiB disk allowance). It
also runs containers, small CPU PyTorch experiments, and small local CPU LLMs
(≤14B-class) as a secondary, occasional use. GPU execution and Kubeflow belong
to the separate `idvoretskyi/akamai-lke-gpu-cluster` repository and cluster,
not this VM.

## Layout

- `tofu/main.tf`: instance, resize policy, and optional firewall.
- `tofu/variables.tf`, `locals.tf`, `data.tf`: inputs and resolved defaults.
- `tofu/cloud-init/main.yaml.tpl`: first-boot system and user configuration.
- `tofu/cloud-init/devbox-init.sh.tpl`: first-boot installation script.
- `tofu/terraform.tfvars.example`: non-secret example deployment inputs.
- `.github/workflows/validate.yml`: formatting and configuration checks.

Explicit variables override CLI defaults, which override built-in fallbacks.
Keep defaults, variable descriptions, the example, and README consistent. Pin
deployment identity and plan rather than relying on the operator's environment.
Keep dependencies locked; do not upgrade providers as part of unrelated work.

## Validation

Run from the repository root:

```sh
tofu -chdir=tofu fmt -check -recursive -diff
tofu -chdir=tofu init -backend=false -lockfile=readonly
tofu -chdir=tofu validate
git diff --check
```

For template edits, render with synthetic, non-secret inputs in an isolated
temporary directory. Check rendered YAML and shell syntax without executing
bootstrap scripts. Exercise both optional CLI-seeding and dotfiles branches.
Validation does not prove an existing-instance resize is safe; that requires
the correct deployment state and a separately reviewed infrastructure plan.

## Safety Boundaries

- Repository changes do not authorize infrastructure apply, import, resize,
  rebuild, destroy, reboot, paid services, or changes to the LKE cluster.
- Never apply from missing state. Recover the original deployment state and
  inputs, or perform a separately approved import and reconciliation first.
- Review plans for replacement, deletion, disk, firewall, and metadata changes.
  Stop on unexpected changes; do not mask them with broad `ignore_changes`.
- Run a VM resize from outside that VM. SSH and tmux processes will be lost on
  reboot. Keep `resize_disk = false` unless disk expansion is explicitly approved.
- A downsize only succeeds if the instance's allocated disks already fit the
  target plan's allowance (e.g. 164 GiB for `g8-dedicated-16-4`). Verify this
  before planning; disk shrink is a separate, powered-off, manually approved
  operation, never a side effect of a plan change.
- Paid backups remain disabled. Before disruptive work, identify uncommitted
  changes and local-only data; GitHub only preserves what has been pushed.
- State, plans, tfvars, tokens, passwords, and kubeconfigs may contain secrets.
  Never commit them in plaintext, even to a private repo. If a recovery archive
  is needed, encrypt it and keep the decryption key outside the repository.
  Git is not a state backend with locking. Do not create a repo unnecessarily.
- `deployment_user_data_base64` carries a real deployment's exact boot metadata.
  Set it only in a private, ignored `*.auto.tfvars.json` file, never in
  `terraform.tfvars.example` or any committed file.
- `linode_instance.dev_box` has `prevent_destroy = true`. Do not remove it to
  work around a failing plan; only remove it for a deliberately reviewed,
  separately approved replacement (see README's "Intentional replacement"),
  and prefer restoring the guard afterward.
- Use scoped credentials. Docker-group access and sudo are privileged, not
  agent sandboxes. Avoid printing secrets in tool output or logs.
- Confirm Kubernetes context and namespace before mutations; prefer explicit
  `--context` and `--namespace`. Do not change the global context implicitly.
- Keep k3s optional and disabled at boot. `k3s-down` stops local workloads and
  resets local k3s networking; do not run it without accounting for local jobs.
- Keep PyTorch and pipeline SDKs project-local. Do not install CUDA, full
  Kubeflow, or unbounded training workloads on the dev box by default.
- Keep notebook/dashboard listeners on localhost and use SSH tunnels.
- Cloud-init changes affect new deployments; do not rerun the bootstrap on an
  existing host. Document narrowly scoped host migration steps separately.
- Commit, push, or publish only when requested, and review for secrets first.
