#!/usr/bin/env bash
# 20-docker.sh — Docker CE + buildx + compose.
set -euo pipefail
# shellcheck disable=SC1091
source /etc/devbox/env

if [[ "${INSTALL_DOCKER}" != "true" ]]; then
  echo "[20-docker] skipped (INSTALL_DOCKER=$INSTALL_DOCKER)"
  exit 0
fi

export DEBIAN_FRONTEND=noninteractive

# shellcheck disable=SC1091
. /etc/os-release

case "${ID:-}" in
  ubuntu) docker_distro="ubuntu" ;;
  debian) docker_distro="debian" ;;
  *)
    echo "[20-docker] unsupported distro '${ID:-unknown}' — only ubuntu and debian are supported"
    exit 1
    ;;
esac

install -m 0755 -d /etc/apt/keyrings
curl -fsSL "https://download.docker.com/linux/${docker_distro}/gpg" \
  | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

codename="${UBUNTU_CODENAME:-${VERSION_CODENAME:-}}"

cat >/etc/apt/sources.list.d/docker.list <<EOF
deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/${docker_distro} ${codename} stable
EOF

apt-get update -y
apt-get install -y --no-install-recommends \
  docker-ce \
  docker-ce-cli \
  containerd.io \
  docker-buildx-plugin \
  docker-compose-plugin

usermod -aG docker "${DEVBOX_USER}"
systemctl enable --now docker

echo "[20-docker] done"
