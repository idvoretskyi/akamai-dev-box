#!/usr/bin/env bash
# 80-shell.sh — zsh + oh-my-zsh + powerlevel10k + tmux/TPM + modern CLI essentials.
set -euo pipefail
# shellcheck disable=SC1091
source /etc/devbox/env

if [[ "${INSTALL_SHELL_STACK}" != "true" ]]; then
  echo "[80-shell] skipped (INSTALL_SHELL_STACK=$INSTALL_SHELL_STACK)"
  exit 0
fi

export DEBIAN_FRONTEND=noninteractive

# shellcheck disable=SC1091
. /etc/os-release

###############################################################################
# 1. System packages
###############################################################################

apt-get install -y --no-install-recommends \
  zsh \
  tmux \
  fzf \
  zoxide \
  eza \
  bat \
  ncdu \
  btop \
  git-delta \
  fonts-powerline \
  unzip \
  less \
  locales

# GitHub CLI — official apt repo (works on both ubuntu and debian).
if ! command -v gh >/dev/null 2>&1; then
  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
  chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    >/etc/apt/sources.list.d/github-cli.list
  apt-get update -y
  apt-get install -y --no-install-recommends gh
fi

# Ensure en_US.UTF-8 locale is available (needed by p10k / omz).
sed -i 's/^# *en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
locale-gen

###############################################################################
# 2. Set zsh as the default shell for the dev user
###############################################################################

zsh_path="$(command -v zsh)"
if ! grep -qxF "${zsh_path}" /etc/shells; then
  echo "${zsh_path}" >>/etc/shells
fi
chsh -s "${zsh_path}" "${DEVBOX_USER}"

user_home="$(getent passwd "${DEVBOX_USER}" | cut -d: -f6)"

###############################################################################
# 3. oh-my-zsh (unattended — does not overwrite existing install)
###############################################################################

sudo -iu "${DEVBOX_USER}" bash -lc '
  if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
    RUNZSH=no CHSH=no \
      sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  fi
'

###############################################################################
# 4. Powerlevel10k theme
###############################################################################

sudo -iu "${DEVBOX_USER}" bash -lc '
  zsh_custom="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
  [[ -d "$zsh_custom/themes/powerlevel10k" ]] || \
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git \
      "$zsh_custom/themes/powerlevel10k"
'

###############################################################################
# 5. zsh plugins: autosuggestions + syntax-highlighting
###############################################################################

sudo -iu "${DEVBOX_USER}" bash -lc '
  zsh_custom="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
  [[ -d "$zsh_custom/plugins/zsh-autosuggestions" ]] || \
    git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions \
      "$zsh_custom/plugins/zsh-autosuggestions"
  [[ -d "$zsh_custom/plugins/zsh-syntax-highlighting" ]] || \
    git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting \
      "$zsh_custom/plugins/zsh-syntax-highlighting"
'

###############################################################################
# 6. ~/.zshrc
###############################################################################

cat >"${user_home}/.zshrc" <<'ZSHRC'
# Powerlevel10k instant prompt — must be near the top of .zshrc.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"

plugins=(
  git
  docker
  docker-compose
  kubectl
  helm
  golang
  rust
  python
  pip
  fzf
  zoxide
  tmux
  terraform
  zsh-autosuggestions
  zsh-syntax-highlighting
)

source "$ZSH/oh-my-zsh.sh"

# Convenience aliases
alias k=kubectl
alias ls='eza --icons'
alias ll='eza -lah --icons --git'
alias lt='eza --tree --icons'
alias cat='bat --paging=never'
alias diff='delta'

# Source system-wide profile.d scripts (Go, fnm, etc.)
for f in /etc/profile.d/*.sh; do [[ -r "$f" ]] && source "$f"; done

# Cargo / Rust
[[ -f "$HOME/.cargo/env" ]] && source "$HOME/.cargo/env"

# zoxide — smarter cd
eval "$(zoxide init zsh)"

# p10k config
[[ -f "$HOME/.p10k.zsh" ]] && source "$HOME/.p10k.zsh"
ZSHRC

###############################################################################
# 7. ~/.p10k.zsh — lean preset (user can re-run `p10k configure` to customise)
###############################################################################

curl -fsSL \
  https://raw.githubusercontent.com/romkatv/powerlevel10k/master/config/p10k-lean.zsh \
  -o "${user_home}/.p10k.zsh"

###############################################################################
# 8. ~/.tmux.conf + TPM
###############################################################################

sudo -iu "${DEVBOX_USER}" bash -lc '
  [[ -d "$HOME/.tmux/plugins/tpm" ]] || \
    git clone --depth=1 https://github.com/tmux-plugins/tpm \
      "$HOME/.tmux/plugins/tpm"
'

cat >"${user_home}/.tmux.conf" <<'TMUXCONF'
# True colour
set -g default-terminal "tmux-256color"
set -ga terminal-overrides ",*256col*:Tc"

# Quality-of-life defaults
set -g mouse on
set -g history-limit 50000
set -g base-index 1
setw -g pane-base-index 1
set -g renumber-windows on
set -g escape-time 10
set -g focus-events on

# Prefix: C-b primary, C-a secondary
set -g prefix2 C-a
bind C-a send-prefix -2

# Splits keep current path
bind | split-window -h -c "#{pane_current_path}"
bind - split-window -v -c "#{pane_current_path}"
unbind '"'
unbind '%'

# Reload config
bind r source-file ~/.tmux.conf \; display "Config reloaded"

# Plugins
set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'tmux-plugins/tmux-sensible'
set -g @plugin 'tmux-plugins/tmux-resurrect'
set -g @plugin 'tmux-plugins/tmux-continuum'
set -g @continuum-restore 'on'

run '~/.tmux/plugins/tpm/tpm'
TMUXCONF

# Install TPM plugins headlessly
sudo -iu "${DEVBOX_USER}" bash -lc \
  'TMUX_PLUGIN_MANAGER_PATH="$HOME/.tmux/plugins" \
   "$HOME/.tmux/plugins/tpm/scripts/install_plugins.sh" >/dev/null 2>&1' || true

###############################################################################
# 9. git-delta config in ~/.gitconfig
###############################################################################

sudo -iu "${DEVBOX_USER}" bash -lc '
  git config --global core.pager delta
  git config --global interactive.diffFilter "delta --color-only"
  git config --global delta.navigate true
  git config --global delta.light false
  git config --global merge.conflictstyle diff3
  git config --global diff.colorMoved default
'

###############################################################################
# 10. Fix ownership
###############################################################################

chown -R "${DEVBOX_USER}:${DEVBOX_USER}" "${user_home}"

echo "[80-shell] done"
