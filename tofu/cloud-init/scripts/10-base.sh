#!/usr/bin/env bash
# 10-base.sh — apt baseline, sysctl tuning for container workloads, zram.
set -euo pipefail
# shellcheck disable=SC1091
source /etc/devbox/env

export DEBIAN_FRONTEND=noninteractive

apt-get update -y
apt-get install -y --no-install-recommends \
  build-essential \
  wget \
  zram-tools

# Sysctl tuning for container workloads.
cat >/etc/sysctl.d/99-devbox.conf <<EOF
fs.inotify.max_user_instances=8192
fs.inotify.max_user_watches=524288
vm.max_map_count=262144
net.ipv4.ip_forward=1
vm.swappiness=100
EOF
sysctl --system >/dev/null

# zram: compressed in-memory swap (half of RAM, lz4).
cat >/etc/default/zramswap <<EOF
ALGO=lz4
PERCENT=50
EOF
systemctl enable --now zramswap

echo "[10-base] done"
