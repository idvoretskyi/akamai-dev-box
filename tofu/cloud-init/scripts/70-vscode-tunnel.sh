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

# Static MOTD with first-run instructions.
tunnel_name="${VSCODE_TUNNEL_NAME:-$(hostname)}"
cat >/etc/motd <<EOF

  akamai-dev-box

  Cloud-init log:  sudo tail -f /var/log/devbox-init.log
  Ready marker:    /var/lib/devbox-init.done
  Kubeconfig:      ~/.kube/config (k3s)

  Start a tmux session:
    tmux new -s dev

  First-time VSCode tunnel setup (run once as your user):
    code tunnel user login --provider github
    sudo loginctl enable-linger \$USER
    code tunnel service install --name ${tunnel_name}

  Then open: https://vscode.dev/tunnel/${tunnel_name}

EOF

echo "[70-vscode-tunnel] done"
