#!/usr/bin/env bash
# Render the cloud-init templates with synthetic, non-secret inputs and check
# the result offline: YAML parses, cloud-init's schema accepts it, the first-boot
# script passes `bash -n` (and shellcheck when installed), no template syntax is
# left unrendered, and the payload fits Linode's user_data limit. Exercises both
# the all-features and the all-optional-branches-off scenarios. Never executes
# the bootstrap script.
#
# Usage: scripts/check-cloud-init.sh   (needs tofu or terraform, and python3 + PyYAML)
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tf="$(command -v tofu || command -v terraform || { echo "tofu or terraform required" >&2; exit 2; })"
work="$(mktemp -d "${TMPDIR:-/tmp}/devbox-render.XXXXXX")"
trap 'rm -rf "$work"' EXIT

cp -r "$repo/tofu/cloud-init" "$work/cloud-init"

cat > "$work/main.tf" <<'TF'
locals {
  key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIExampleExampleExampleExampleExampleExample test@example"

  full_init = templatefile("${path.module}/cloud-init/devbox-init.sh.tpl", {
    username      = "dev"
    dotfiles_repo = "https://github.com/example/dotfiles.git"
  })
  min_init = templatefile("${path.module}/cloud-init/devbox-init.sh.tpl", {
    username      = "dev"
    dotfiles_repo = ""
  })
}

output "full_script" { value = local.full_init }
output "min_script" { value = local.min_init }

output "full_yaml" {
  value = templatefile("${path.module}/cloud-init/main.yaml.tpl", {
    username           = "dev"
    hostname           = "dev-box"
    timezone           = "Europe/Kyiv"
    ssh_keys           = [local.key]
    extra_packages     = ["sqlite3"]
    seed_linode_cli    = true
    linode_token       = "synthetic-not-a-real-token"
    region             = "gb-lon"
    instance_type      = "g8-dedicated-16-4"
    image              = "linode/ubuntu26.04"
    git_user_name      = "Test User"
    git_user_email     = "test@example.com"
    devbox_init_script = local.full_init
  })
}

output "min_yaml" {
  value = templatefile("${path.module}/cloud-init/main.yaml.tpl", {
    username           = "dev"
    hostname           = "dev-box"
    timezone           = "UTC"
    ssh_keys           = [local.key]
    extra_packages     = []
    seed_linode_cli    = false
    linode_token       = null
    region             = "gb-lon"
    instance_type      = "g8-dedicated-16-4"
    image              = "linode/ubuntu26.04"
    git_user_name      = null
    git_user_email     = null
    devbox_init_script = local.min_init
  })
}
TF

(cd "$work" && "$tf" init -backend=false -input=false > /dev/null && "$tf" apply -auto-approve -input=false > /dev/null)

fail=0
for scenario in full min; do
  (cd "$work" && "$tf" output -raw "${scenario}_yaml") > "$work/$scenario.yaml"
  (cd "$work" && "$tf" output -raw "${scenario}_script") > "$work/$scenario.sh"

  if grep -nE '\$\{|%\{' "$work/$scenario.yaml" "$work/$scenario.sh"; then
    echo "FAIL [$scenario]: unrendered template syntax" >&2
    fail=1
  fi

  python3 - "$work/$scenario.yaml" "$scenario" <<'PY' || fail=1
import sys, yaml
path, name = sys.argv[1:3]
doc = yaml.safe_load(open(path))
assert isinstance(doc, dict), "cloud-config must be a mapping"
paths = [f["path"] for f in doc["write_files"]]
seeded = "/home/dev/.config/linode-cli/cli" in paths
assert seeded == (name == "full"), "linode-cli seeding presence wrong for " + name
# Third-party apt sources must not exist before their keyrings do.
assert not [p for p in paths if p.startswith("/etc/apt/sources.list.d/")], "apt sources belong in the bootstrap"
assert "/etc/sudoers.d/90-devbox-nopasswd" not in paths, "duplicate sudo rule reintroduced"
print("ok   [%s] yaml" % name)
PY

  bash -n "$work/$scenario.sh" && echo "ok   [$scenario] bash -n"
  if command -v shellcheck > /dev/null; then
    shellcheck -s bash -S warning "$work/$scenario.sh" && echo "ok   [$scenario] shellcheck"
  else
    echo "skip [$scenario] shellcheck not installed"
  fi

  if command -v cloud-init > /dev/null; then
    if out="$(cloud-init schema --config-file "$work/$scenario.yaml" 2>&1)"; then
      echo "ok   [$scenario] cloud-init schema"
    else
      echo "FAIL [$scenario]: cloud-init schema" >&2
      echo "$out" >&2
      fail=1
    fi
  else
    echo "skip [$scenario] cloud-init not installed"
  fi

  size="$(wc -c < "$work/$scenario.yaml")"
  echo "info [$scenario] user_data: $size bytes (Linode limit 65535)"
  [ "$size" -lt 65535 ] || { echo "FAIL [$scenario]: user_data too large" >&2; fail=1; }
done

exit "$fail"
