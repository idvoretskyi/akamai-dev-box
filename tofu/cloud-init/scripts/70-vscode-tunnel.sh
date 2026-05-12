#!/usr/bin/env bash
# 70-vscode-tunnel.sh — install the standalone `code` CLI and write MOTD.
set -euo pipefail
# shellcheck disable=SC1091
source /etc/devbox/env

if [[ "${INSTALL_VSCODE_TUNNEL}" != "true" ]]; then
  echo "[70-vscode-tunnel] skipped"
  exit 0
fi

arch="$(dpkg --print-architecture)"
case "$arch" in
  amd64) cli_arch="cli-linux-x64" ;;
  arm64) cli_arch="cli-linux-arm64" ;;
  *) echo "unsupported arch: $arch"; exit 1 ;;
esac

if ! command -v code >/dev/null; then
  tmp="$(mktemp -d)"
  curl -sfL "https://update.code.visualstudio.com/latest/${cli_arch}/stable" -o "$tmp/code.tar.gz"
  tar -xzf "$tmp/code.tar.gz" -C "$tmp"
  install -m 0755 "$tmp/code" /usr/local/bin/code
  rm -rf "$tmp"
fi

# Clear MOTD — no login noise.
truncate -s 0 /etc/motd
chmod -x /etc/update-motd.d/* 2>/dev/null || true

echo "[70-vscode-tunnel] done"
