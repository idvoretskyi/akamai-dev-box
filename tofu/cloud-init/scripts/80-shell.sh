#!/usr/bin/env bash
# 80-shell.sh — zsh + oh-my-zsh (robbyrussell) + tmux (Nord powerline) + modern CLI essentials.
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
  zsh tmux fzf zoxide eza bat git-delta \
  unzip less locales

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

# zsh plugins
sudo -iu "${DEVBOX_USER}" bash -l <<'HEREDOC'
c="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins"
[[ -d "$c/zsh-autosuggestions" ]] || git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions "$c/zsh-autosuggestions"
[[ -d "$c/zsh-syntax-highlighting" ]] || git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting "$c/zsh-syntax-highlighting"
HEREDOC

# ~/.zshrc
cat >"${user_home}/.zshrc" <<'ZSHRC'
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="robbyrussell"
plugins=(git docker docker-compose kubectl helm golang python pip fzf zoxide tmux terraform gh opentofu command-not-found zsh-autosuggestions zsh-syntax-highlighting)
source "$ZSH/oh-my-zsh.sh"
alias k=kubectl
alias ll='eza -lah --icons --git'
alias ls='eza --icons'
alias lt='eza --tree --icons'
alias cat='bat --paging=never'
alias diff='delta'
for f in /etc/profile.d/*.sh; do [[ -r "$f" ]] && source "$f"; done
[[ -f "$HOME/.cargo/env" ]] && source "$HOME/.cargo/env"
eval "$(zoxide init zsh)"
ZSHRC

# ~/.tmux.conf — Nord powerline (mirrors local ~/.tmux.conf)
cat >"${user_home}/.tmux.conf" <<'TMUXCONF'
# Tmux Configuration with Powerline Styling
# Modern, lightweight tmux config with fancy powerline appearance

# ============================================================================
# General Settings
# ============================================================================

# Set true color support
set -g default-terminal "tmux-256color"
set -ga terminal-overrides ",*256col*:Tc"

# OSC 52 clipboard — copies through SSH to local Mac clipboard
set -s set-clipboard on

# Set prefix to Ctrl-a (more comfortable than Ctrl-b)
unbind C-b
set -g prefix C-a
bind C-a send-prefix

# Reload config file
bind r source-file ~/.tmux.conf \; display "Config reloaded!"

# Enable mouse support
set -g mouse on

# Start window and pane numbering at 1
set -g base-index 1
set -g pane-base-index 1
set-window-option -g pane-base-index 1
set-option -g renumber-windows on

# Don't exit from tmux when closing a session
set -g detach-on-destroy off

# Increase scrollback buffer size
set -g history-limit 50000

# Display time for messages
set -g display-time 4000

# Refresh status more often
set -g status-interval 5

# Focus events enabled for terminals that support them
set -g focus-events on

# Disable automatic window renaming
set-option -g allow-rename off

# Address vim mode switching delay
set -s escape-time 0

# Increase repeat time for repeatable commands
set -g repeat-time 1000

# Rather than constraining window size to the maximum size of any client
# connected to the *session*, constrain window size to the maximum size
# of any client connected to *that window*
setw -g aggressive-resize on

# Bell settings
set -g bell-action none
set -g visual-bell off

# Activity monitoring
setw -g monitor-activity on
set -g visual-activity off

# ============================================================================
# Key Bindings
# ============================================================================

# Split panes with | and -
bind | split-window -h -c "#{pane_current_path}"
bind - split-window -v -c "#{pane_current_path}"
unbind '"'
unbind %

# Switch panes using Alt-arrow without prefix
bind -n M-Left select-pane -L
bind -n M-Right select-pane -R
bind -n M-Up select-pane -U
bind -n M-Down select-pane -D

# Vim-style pane switching
bind h select-pane -L
bind j select-pane -D
bind k select-pane -U
bind l select-pane -R

# Resize panes
bind -r H resize-pane -L 5
bind -r J resize-pane -D 5
bind -r K resize-pane -U 5
bind -r L resize-pane -R 5

# Quick window selection
bind -n M-1 select-window -t 1
bind -n M-2 select-window -t 2
bind -n M-3 select-window -t 3
bind -n M-4 select-window -t 4
bind -n M-5 select-window -t 5

# Copy mode with vi keys
setw -g mode-keys vi
bind-key -T copy-mode-vi v send-keys -X begin-selection
bind-key -T copy-mode-vi y send-keys -X copy-pipe-and-cancel
bind-key -T copy-mode-vi r send-keys -X rectangle-toggle

# New window in current path
bind c new-window -c "#{pane_current_path}"

# ============================================================================
# Color Scheme & Powerline Styling
# ============================================================================

# Color palette (Nord-inspired with powerline elements)
%hidden MODULE_SEPARATOR=""
%hidden LEFT_SEPARATOR=""
%hidden RIGHT_SEPARATOR=""

# ============================================================================
# Status Bar Configuration
# ============================================================================

# Status bar general
set -g status on
set -g status-position bottom
set -g status-justify left
set -g status-bg "#2E3440"
set -g status-fg "#D8DEE9"
set -g status-left-length 50
set -g status-right-length 150

# Left side - Session info with powerline
set -g status-left "#[bg=#5E81AC,fg=#2E3440,bold] #S #[bg=#2E3440,fg=#5E81AC]"

# Right side - System info with powerline segments
set -g status-right "#[fg=#4C566A]#[bg=#4C566A,fg=#D8DEE9] %H:%M #[bg=#4C566A,fg=#88C0D0]#[bg=#88C0D0,fg=#2E3440] %d-%b #[bg=#88C0D0,fg=#5E81AC]#[bg=#5E81AC,fg=#2E3440,bold] #h "

# Window status
setw -g window-status-format "#[fg=#D8DEE9,bg=#3B4252] #I #[fg=#D8DEE9,bg=#3B4252]#W "
setw -g window-status-current-format "#[fg=#2E3440,bg=#EBCB8B]#[fg=#2E3440,bg=#EBCB8B,bold] #I #W #[fg=#EBCB8B,bg=#2E3440]"

# Window status styling
setw -g window-status-activity-style "fg=#D8DEE9,bg=#BF616A"
setw -g window-status-separator ""

# ============================================================================
# Pane Styling
# ============================================================================

# Pane borders
set -g pane-border-style "fg=#4C566A"
set -g pane-active-border-style "fg=#5E81AC"

# Message styling
set -g message-style "bg=#5E81AC,fg=#2E3440"
set -g message-command-style "bg=#5E81AC,fg=#2E3440"

# Mode styling (copy mode, etc.)
setw -g mode-style "bg=#EBCB8B,fg=#2E3440"
TMUXCONF

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
