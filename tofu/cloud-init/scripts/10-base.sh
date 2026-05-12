#!/usr/bin/env bash
# 10-base.sh — apt baseline, sysctl tuning for k3s, swap.
set -euo pipefail
# shellcheck disable=SC1091
source /etc/devbox/env

export DEBIAN_FRONTEND=noninteractive

apt-get update -y
apt-get install -y --no-install-recommends \
  build-essential \
  apt-transport-https \
  wget \
  ripgrep \
  fd-find \
  bat \
  neovim

# Sysctl tuning for k3s + container workloads.
cat >/etc/sysctl.d/99-devbox.conf <<EOF
fs.inotify.max_user_instances=8192
fs.inotify.max_user_watches=524288
vm.max_map_count=262144
net.ipv4.ip_forward=1
EOF
sysctl --system >/dev/null

# 2 GB swap if not already present.
if ! swapon --show | grep -q .; then
  fallocate -l 2G /swapfile
  chmod 600 /swapfile
  mkswap /swapfile >/dev/null
  swapon /swapfile
  echo '/swapfile none swap sw 0 0' >>/etc/fstab
fi

echo "[10-base] done"
