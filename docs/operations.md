# Operations

Runbooks and cost notes for the existing dev box. Repository safety rules live in [AGENTS.md](../AGENTS.md).

## Billing and plans

- G8 Dedicated plans are billed hourly with **no monthly cap** since 2026-07-01. Monthly figures in the README are indicative (London hourly rate x ~730 h), excluding taxes, additional services, and usage.
- `id-cgk` and `br-gru` carry a regional uplift (roughly +20% and +40%).
- Plan sizes use Linode's GB labels; for resize safety rely on API-reported MiB totals (see below).
- `g6-standard-6` is a shared-CPU alternative with the same RAM and disk, and it still has bundled transfer.
- The previous baseline was `g7-dedicated-16-8` (8 dedicated Zen 3 vCPUs / 16 GiB / 320 GiB disk, $173/month cap, 6 TB bundled transfer). Its larger disk may suit workloads that do not fit `g8-dedicated-16-8`.
- Resizing more than once in a billing month gives one prorated invoice line per plan used. The invoice is noisier, not larger.

See [Understanding how billing works](https://techdocs.akamai.com/cloud-computing/docs/understanding-how-billing-works).

## Network transfer

G8 Dedicated plans have no bundled outbound allowance. All outbound traffic is billed at usage-based rates ($0.005/GiB in `gb-lon`), regardless of the account's transfer pool.

- Coding-agent traffic is mostly request bodies: typically single-digit GiB/month, i.e. cents.
- Check usage: `linode-cli linodes transfer-view <linode-id>`.
- Break-even against `g7-dedicated-16-8` is about 4 TiB/month of outbound.
- If a cluster (e.g. LKE running Ollama) talks to this box, put it in `gb-lon` and use a VPC or IPv6 address. Same-datacenter private traffic is unmetered.

## Resize an existing instance

Configuration changes alone never resize an instance.

1. Work from the machine that owns the deployment state (not the dev box being resized, and never from missing state).
2. Push every working repository and back up local-only data. A resize reboots the box; SSH and tmux sessions do not survive.
3. **Downsizing:** the target plan's disk allowance must already fit the current disks. Compare exact MiB totals, not GB labels. `g8-dedicated-16-4` is labelled 160 GB but its API allowance is 167,936 MiB; the existing instance's disks total 163,840 MiB (163,328 ext4 + 512 swap), so they fit. Check with `linode-cli linodes disks-list <id>`. Disk shrink is a separate, powered-off, manually approved step.
4. Write the original `metadata.user_data` from verified state into a private, ignored file. Do not print it: it may embed the API token if `seed_linode_cli` was enabled.

   ```sh
   (umask 077 && tofu -chdir=tofu show -json | jq \
     '{deployment_user_data_base64: (.values.root_module.resources[]
       | select(.address=="linode_instance.dev_box") | .values.metadata[0].user_data)}' \
     > tofu/zz-existing-deployment.auto.tfvars.json)
   ```

   Never `cat`, log, or commit that file. Any other diff in the rendered cloud-init forces replacement (`user_data` is `ForceNew`), which `prevent_destroy` blocks.
5. Change only `instance_type`. Save a plan and confirm a single in-place `type` update: no replacement, disk, or firewall changes.
6. Apply in a maintenance window (cold migration = reboot). Reconnect and verify `nproc`, `free -h`, `df -h`, `swapon --show`, `systemctl --failed`. zram adjusts to RAM/2 on reboot.

If startup fails, use Lish to investigate rather than rebuilding.

## Intentional replacement

Only when reconciliation is not feasible.

1. Remove or comment out `prevent_destroy = true` in `tofu/main.tf` as a deliberate, reviewed change.
2. Review inputs as for a fresh deployment (leave `deployment_user_data_base64` unset).
3. Confirm the plan shows only the expected `-/+` replacement (plus the firewall reattaching).
4. Apply, then update SSH config with the `ssh_config_install_command` / `ssh_config_remove_command` outputs and reauthenticate agents.
5. Restore `prevent_destroy = true`.

Never commit plaintext state, tfvars, tokens, or kubeconfigs.
