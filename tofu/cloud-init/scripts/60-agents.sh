#!/usr/bin/env bash
# 60-agents.sh — Claude Code + OpenCode CLIs via npm (user-scope).
set -euo pipefail
# shellcheck disable=SC1091
source /etc/devbox/env

if [[ "${INSTALL_CLAUDE_CODE}" != "true" && "${INSTALL_OPENCODE}" != "true" ]]; then
  echo "[60-agents] skipped (both agents disabled)"
  exit 0
fi

# We rely on fnm + Node LTS being installed for the user by 50-langs.sh.
if ! sudo -iu "${DEVBOX_USER}" bash -lc 'command -v npm >/dev/null 2>&1'; then
  echo "[60-agents] npm not available for ${DEVBOX_USER} (Node not installed?); skipping agents"
  exit 0
fi

pkgs=()
[[ "${INSTALL_CLAUDE_CODE}" == "true" ]] && pkgs+=("@anthropic-ai/claude-code")
[[ "${INSTALL_OPENCODE}" == "true" ]]    && pkgs+=("opencode-ai")

sudo -iu "${DEVBOX_USER}" bash -lc "npm install -g ${pkgs[*]}"

echo "[60-agents] installed: ${pkgs[*]}"
