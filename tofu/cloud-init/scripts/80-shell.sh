#!/usr/bin/env bash
# 80-shell.sh — zsh + oh-my-zsh + powerlevel10k + tmux/TPM + modern CLI essentials.
set -euo pipefail
# shellcheck disable=SC1091
source /etc/devbox/env

if [[ "${INSTALL_SHELL_STACK}" != "true" ]]; then
  echo "[80-shell] skipped"; exit 0
fi

export DEBIAN_FRONTEND=noninteractive
# shellcheck disable=SC1091
. /etc/os-release

# System packages
apt-get install -y --no-install-recommends \
  zsh tmux fzf zoxide eza bat ncdu btop git-delta \
  fonts-powerline unzip less locales

# GitHub CLI
if ! command -v gh >/dev/null 2>&1; then
  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
  chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    >/etc/apt/sources.list.d/github-cli.list
  apt-get update -y
  apt-get install -y --no-install-recommends gh
fi

# Locale
sed -i 's/^# *en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen && locale-gen

# Default shell
zsh_path="$(command -v zsh)"
grep -qxF "${zsh_path}" /etc/shells || echo "${zsh_path}" >>/etc/shells
chsh -s "${zsh_path}" "${DEVBOX_USER}"

user_home="$(getent passwd "${DEVBOX_USER}" | cut -d: -f6)"

# oh-my-zsh
sudo -iu "${DEVBOX_USER}" bash -l <<'HEREDOC'
[[ -d "$HOME/.oh-my-zsh" ]] && exit 0
RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
HEREDOC

# powerlevel10k
sudo -iu "${DEVBOX_USER}" bash -l <<'HEREDOC'
d="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"
[[ -d "$d" ]] || git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$d"
HEREDOC

# zsh plugins
sudo -iu "${DEVBOX_USER}" bash -l <<'HEREDOC'
c="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins"
[[ -d "$c/zsh-autosuggestions" ]] || git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions "$c/zsh-autosuggestions"
[[ -d "$c/zsh-syntax-highlighting" ]] || git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting "$c/zsh-syntax-highlighting"
HEREDOC

# ~/.zshrc
cat >"${user_home}/.zshrc" <<'ZSHRC'
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"
plugins=(git docker docker-compose kubectl helm golang rust python pip fzf zoxide tmux terraform zsh-autosuggestions zsh-syntax-highlighting)
source "$ZSH/oh-my-zsh.sh"
alias k=kubectl ll='eza -lah --icons --git' ls='eza --icons' lt='eza --tree --icons' cat='bat --paging=never' diff='delta'
for f in /etc/profile.d/*.sh; do [[ -r "$f" ]] && source "$f"; done
[[ -f "$HOME/.cargo/env" ]] && source "$HOME/.cargo/env"
eval "$(zoxide init zsh)"
[[ -f "$HOME/.p10k.zsh" ]] && source "$HOME/.p10k.zsh"
ZSHRC

# p10k lean preset
curl -fsSL https://raw.githubusercontent.com/romkatv/powerlevel10k/master/config/p10k-lean.zsh \
  -o "${user_home}/.p10k.zsh"

# TPM
sudo -iu "${DEVBOX_USER}" bash -l <<'HEREDOC'
[[ -d "$HOME/.tmux/plugins/tpm" ]] || git clone --depth=1 https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
HEREDOC

# ~/.tmux.conf
cat >"${user_home}/.tmux.conf" <<'TMUXCONF'
set -g default-terminal "tmux-256color"
set -ga terminal-overrides ",*256col*:Tc"
set -g mouse on
set -g history-limit 50000
set -g base-index 1
setw -g pane-base-index 1
set -g renumber-windows on
set -g escape-time 10
set -g focus-events on
set -g prefix2 C-a
bind C-a send-prefix -2
bind | split-window -h -c "#{pane_current_path}"
bind - split-window -v -c "#{pane_current_path}"
unbind '"'
unbind '%'
bind r source-file ~/.tmux.conf \; display "Reloaded"
set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'tmux-plugins/tmux-sensible'
set -g @plugin 'tmux-plugins/tmux-resurrect'
set -g @plugin 'tmux-plugins/tmux-continuum'
set -g @continuum-restore 'on'
run '~/.tmux/plugins/tpm/tpm'
TMUXCONF

sudo -iu "${DEVBOX_USER}" bash -lc \
  'TMUX_PLUGIN_MANAGER_PATH="$HOME/.tmux/plugins" "$HOME/.tmux/plugins/tpm/scripts/install_plugins.sh" >/dev/null 2>&1' || true

# git-delta config
sudo -iu "${DEVBOX_USER}" bash -l <<'HEREDOC'
git config --global core.pager delta
git config --global interactive.diffFilter "delta --color-only"
git config --global delta.navigate true
git config --global delta.light false
git config --global merge.conflictstyle diff3
git config --global diff.colorMoved default
HEREDOC

chown -R "${DEVBOX_USER}:${DEVBOX_USER}" "${user_home}"
echo "[80-shell] done"
