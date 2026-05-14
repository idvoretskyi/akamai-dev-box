#!/usr/bin/env bash
# 10-base.sh — apt baseline, swap.
set -euo pipefail
# shellcheck disable=SC1091
source /etc/devbox/env

export DEBIAN_FRONTEND=noninteractive

apt-get update -y
apt-get install -y --no-install-recommends \
  build-essential \
  wget

# 2 GB swap if not already present.
if ! swapon --show | grep -q .; then
  fallocate -l 2G /swapfile
  chmod 600 /swapfile
  mkswap /swapfile >/dev/null
  swapon /swapfile
  echo '/swapfile none swap sw 0 0' >>/etc/fstab
fi

echo "[10-base] done"
