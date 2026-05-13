#!/usr/bin/env bash
# 40-kube-tools.sh — kubectl, helm, k9s, stern, yq.
set -euo pipefail
# shellcheck disable=SC1091
source /etc/devbox/env

arch="$(dpkg --print-architecture)"   # amd64 / arm64
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

install_bin() { install -m 0755 "$1" "/usr/local/bin/$(basename "$1")"; }

# --- kubectl (stable) ---
if ! command -v kubectl >/dev/null; then
  ver="$(curl -sfL https://dl.k8s.io/release/stable.txt)"
  curl -sfLo "$tmp/kubectl" "https://dl.k8s.io/release/${ver}/bin/linux/${arch}/kubectl"
  install_bin "$tmp/kubectl"
fi

# Convenience symlink: k -> kubectl (installed above).
ln -sf /usr/local/bin/kubectl /usr/local/bin/k || true

# --- helm ---
if ! command -v helm >/dev/null; then
  curl -sfL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash >/dev/null
fi

# --- k9s ---
if ! command -v k9s >/dev/null; then
  curl -sfL "https://github.com/derailed/k9s/releases/latest/download/k9s_Linux_${arch}.tar.gz" \
    | tar -xz -C "$tmp" k9s
  install_bin "$tmp/k9s"
fi

# --- stern ---
if ! command -v stern >/dev/null; then
  stern_ver="$(curl -sfL https://api.github.com/repos/stern/stern/releases/latest | jq -r .tag_name | sed 's/^v//')"
  curl -sfL "https://github.com/stern/stern/releases/download/v${stern_ver}/stern_${stern_ver}_linux_${arch}.tar.gz" \
    | tar -xz -C "$tmp" stern
  install_bin "$tmp/stern"
fi

# --- yq ---
if ! command -v yq >/dev/null; then
  curl -sfLo "$tmp/yq" "https://github.com/mikefarah/yq/releases/latest/download/yq_linux_${arch}"
  install_bin "$tmp/yq"
fi

echo "[40-kube-tools] done"
