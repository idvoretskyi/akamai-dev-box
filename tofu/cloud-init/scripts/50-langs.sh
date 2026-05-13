#!/usr/bin/env bash
# 50-langs.sh — Go, Node (via fnm), Python (uv), Rust (rustup).
set -euo pipefail
# shellcheck disable=SC1091
source /etc/devbox/env

arch="$(dpkg --print-architecture)"   # amd64 / arm64

want() { [[ " ${INSTALL_LANGUAGES} " == *" $1 "* ]]; }

# --- Go ---
if want go && [[ ! -x /usr/local/go/bin/go ]]; then
  go_ver="$(curl -sfL https://go.dev/VERSION?m=text | head -n1)"
  curl -sfL "https://go.dev/dl/${go_ver}.linux-${arch}.tar.gz" | tar -xz -C /usr/local
  cat >/etc/profile.d/go.sh <<'EOF'
export PATH="/usr/local/go/bin:$PATH"
export GOPATH="$HOME/go"
export PATH="$GOPATH/bin:$PATH"
EOF
  chmod +x /etc/profile.d/go.sh
fi

# --- Node via fnm (system-wide binary, per-user installs) ---
if want node && [[ ! -x /usr/local/bin/fnm ]]; then
  fnm_ver="$(curl -sfL https://api.github.com/repos/Schniz/fnm/releases/latest | jq -r .tag_name)"
  asset="fnm-linux"
  [[ "$arch" == "arm64" ]] && asset="fnm-arm64"
  tmp="$(mktemp -d)"
  curl -sfL "https://github.com/Schniz/fnm/releases/download/${fnm_ver}/${asset}.zip" -o "$tmp/fnm.zip"
  unzip -q "$tmp/fnm.zip" -d "$tmp"
  install -m 0755 "$tmp/fnm" /usr/local/bin/fnm
  rm -rf "$tmp"

  cat >/etc/profile.d/fnm.sh <<'EOF'
export FNM_DIR="$HOME/.fnm"
if command -v fnm >/dev/null 2>&1; then
  eval "$(fnm env --shell bash)"
fi
EOF
  chmod +x /etc/profile.d/fnm.sh

  sudo -iu "${DEVBOX_USER}" bash -l <<'HEREDOC'
set -e
export FNM_DIR="$HOME/.fnm"
eval "$(fnm env --shell bash)"
fnm install --lts
fnm default lts-latest
HEREDOC
fi

# --- Python via uv (user-local) ---
if want python; then
  sudo -iu "${DEVBOX_USER}" bash -l <<'HEREDOC'
set -e
if ! command -v uv >/dev/null 2>&1; then
  curl -LsSf https://astral.sh/uv/install.sh | sh
fi
HEREDOC
fi

# --- Rust via rustup (user-local) ---
if want rust; then
  sudo -iu "${DEVBOX_USER}" bash -l <<'HEREDOC'
set -e
if [[ ! -x "$HOME/.cargo/bin/rustc" ]]; then
  curl --proto "=https" --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable --profile default
fi
HEREDOC
fi

echo "[50-langs] done"
