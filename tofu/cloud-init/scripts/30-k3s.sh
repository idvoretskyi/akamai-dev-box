#!/usr/bin/env bash
# 30-k3s.sh — single-node k3s server.
set -euo pipefail
# shellcheck disable=SC1091
source /etc/devbox/env

if [[ "${INSTALL_K3S}" != "true" ]]; then
  echo "[30-k3s] skipped (INSTALL_K3S=$INSTALL_K3S)"
  exit 0
fi

disable_args=()
for c in ${K3S_DISABLE:-}; do
  disable_args+=("--disable=${c}")
done

curl -sfL https://get.k3s.io \
  | INSTALL_K3S_CHANNEL="${K3S_CHANNEL:-stable}" \
    sh -s - server \
    --write-kubeconfig-mode 644 \
    "${disable_args[@]}"

# Wait for the kubeconfig to appear.
for _ in $(seq 1 30); do
  [[ -f /etc/rancher/k3s/k3s.yaml ]] && break
  sleep 2
done

# Drop a kubeconfig in the user's home.
user_home="$(getent passwd "${DEVBOX_USER}" | cut -d: -f6)"
mkdir -p "${user_home}/.kube"
cp /etc/rancher/k3s/k3s.yaml "${user_home}/.kube/config"
chown -R "${DEVBOX_USER}:${DEVBOX_USER}" "${user_home}/.kube"
chmod 600 "${user_home}/.kube/config"

echo "[30-k3s] done"
