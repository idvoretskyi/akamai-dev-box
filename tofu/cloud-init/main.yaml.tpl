#cloud-config

hostname: ${hostname}
fqdn: ${hostname}
preserve_hostname: false
manage_etc_hosts: true
timezone: ${timezone}
locale: en_US.UTF-8

###############################################################################
# APT — disable recommends globally before any package install
###############################################################################
apt:
  conf: |
    APT::Install-Recommends "false";
    APT::Install-Suggests "false";
    APT::Periodic::AutocleanInterval "7";

package_update: true

###############################################################################
# Base packages — lean set tuned for Nanode (1 GB RAM / 25 GB SSD)
# Note: gh is installed via Homebrew (not apt) for Mac parity.
###############################################################################
packages:
  - ca-certificates
  - curl
  - sudo
  - git
  - zsh
  - tmux
  - unzip
  - ncdu
  - rsync
  - less
  - bash-completion
  - locales
  - pipx
  - earlyoom
  - fzf
  - zoxide
  - eza
  - htop
  - build-essential
  - procps
  - file
%{ for p in extra_packages ~}
  - ${p}
%{ endfor ~}

###############################################################################
# Users
###############################################################################
users:
  - name: ${username}
    groups:
      - sudo
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/zsh
    ssh_authorized_keys: ${jsonencode(ssh_keys)}

ssh_pwauth: false

###############################################################################
# Drop-in config files
#
# IMPORTANT: entries targeting /home/${username}/ use defer: true so they are
# written by the write_files_deferred module, which runs AFTER cc_users_groups
# creates the user. Without defer, cloud-init tries to chown the files before
# the user exists, fails, and aborts the entire write_files module — leaving
# the system-level drop-ins unwritten too.
###############################################################################
write_files:

  # ---- System-level files (no defer needed) --------------------------------

  # APT no-recommends (belt-and-suspenders for older cloud-init versions)
  - path: /etc/apt/apt.conf.d/99no-recommends
    content: |
      APT::Install-Recommends "false";
      APT::Install-Suggests "false";

  # Kernel tuning for 1 GB host
  - path: /etc/sysctl.d/99-devbox.conf
    content: |
      # Prefer RAM; use swap only as a safety net
      vm.swappiness = 10
      vm.vfs_cache_pressure = 50
      # Allow memory overcommit (helps fork-heavy workloads like git/pip)
      vm.overcommit_memory = 1
      # TCP: modest tuning for a single-user dev box
      net.core.somaxconn = 1024
      net.ipv4.tcp_fin_timeout = 15
      # File-watcher limit (required by VSCode / language servers)
      fs.inotify.max_user_watches = 524288

  # Journald: cap log size, no double-write to rsyslog
  - path: /etc/systemd/journald.conf.d/size.conf
    content: |
      [Journal]
      Storage=persistent
      Compress=yes
      SystemMaxUse=200M
      RuntimeMaxUse=50M
      ForwardToSyslog=no

  # earlyoom: kill runaway processes before kernel OOM thrashes the box
  - path: /etc/default/earlyoom
    content: |
      EARLYOOM_ARGS="-r 60 -m 5 -s 10"

  # Passwordless sudo for the sudo group (covers our user)
  - path: /etc/sudoers.d/90-devbox-nopasswd
    permissions: '0440'
    content: |
      %sudo ALL=(ALL) NOPASSWD:ALL

  # SSH hardening drop-in (survives openssh-server upgrades)
  - path: /etc/ssh/sshd_config.d/99-devbox.conf
    content: |
      PermitRootLogin no
      PasswordAuthentication no
      KbdInteractiveAuthentication no
      MaxAuthTries 3
      ClientAliveInterval 60
      ClientAliveCountMax 3

  # cloud-init: skip cloud platform probing on subsequent boots
  - path: /etc/cloud/cloud.cfg.d/99-datasource.cfg
    content: |
      datasource_list: [ConfigDrive, NoCloud, None]

  # ---- User home-dir files — defer: true so user exists at write time -------

  # zsh config: oh-my-zsh + agnoster theme + plugins + Homebrew + tool hooks
  # Written to a staging path; runcmd installs omz then moves this into place.
  - path: /home/${username}/.zshrc.devbox
    owner: ${username}:${username}
    permissions: '0644'
    defer: true
    content: |
      # PATH: Homebrew first, then pipx binaries
      if [[ -d /home/linuxbrew/.linuxbrew ]]; then
        eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
      fi
      export PATH="$HOME/.local/bin:$PATH"

      # oh-my-zsh
      export ZSH="$HOME/.oh-my-zsh"

      # Theme: agnoster (powerline-style, pairs with Nord tmux bar).
      # Requires a Nerd Font / Powerline-patched font on the client terminal.
      # Fallback: change to "robbyrussell" if glyphs render as boxes.
      ZSH_THEME="agnoster"

      # Plugins (zsh-autosuggestions + zsh-syntax-highlighting cloned in runcmd)
      plugins=(
        git
        fzf
        zoxide
        zsh-autosuggestions
        zsh-syntax-highlighting
      )

      source "$ZSH/oh-my-zsh.sh"

      # History tuning (supplements omz defaults)
      HISTSIZE=10000
      SAVEHIST=10000
      setopt HIST_EXPIRE_DUPS_FIRST HIST_REDUCE_BLANKS

      # fzf key-bindings (omz fzf plugin handles completion; this adds Ctrl-R etc.)
      [ -f /usr/share/doc/fzf/examples/key-bindings.zsh ] && source /usr/share/doc/fzf/examples/key-bindings.zsh

      # zoxide (smarter cd)
      command -v zoxide &>/dev/null && eval "$(zoxide init zsh --cmd z)"

      # zsh-completions (brew-installed extra completions)
      if type brew &>/dev/null; then
        FPATH="$(brew --prefix)/share/zsh/site-functions:$FPATH"
      fi

      # Completions: linode-cli + gh + everything in ~/.zfunc
      fpath+=~/.zfunc
      autoload -Uz compinit && compinit -C

      # direnv: auto-load .envrc per directory
      command -v direnv &>/dev/null && eval "$(direnv hook zsh)"

      # mise: language version manager
      command -v mise &>/dev/null && eval "$(mise activate zsh)"

      # Mac-parity aliases
      alias ls='eza --color=auto'
      alias ll='eza -lah --git'
      alias la='eza -lah'
      alias open='xdg-open'
      alias gs='git status'
      alias gp='git pull'
      alias gc='git commit'
      alias ..='cd ..'
      alias ...='cd ../..'

      # Auto-attach tmux on interactive SSH login
      if [[ -z "$TMUX" && -n "$SSH_TTY" ]]; then
        tmux attach -t main 2>/dev/null || tmux new-session -s main
      fi

      # k3s: kubeconfig + convenience aliases (start/stop on demand to save RAM)
      export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
      alias k3s-up='sudo systemctl start k3s && echo "k3s started — run: kubectl get nodes"'
      alias k3s-down='sudo systemctl stop k3s && echo "k3s stopped"'
      alias k='kubectl'

  # tmux: Nord powerline-styled, self-contained (no plugin manager)
  - path: /home/${username}/.tmux.conf
    owner: ${username}:${username}
    permissions: '0644'
    defer: true
    content: |
      # Terminal & color
      set -g default-terminal "tmux-256color"
      set -ga terminal-overrides ",*256col*:Tc"

      # Behaviour
      set -g mouse on
      set -g base-index 1
      setw -g pane-base-index 1
      set -g renumber-windows on
      set -g history-limit 5000
      set -sg escape-time 10
      set -g focus-events on

      # Vi keys in copy mode
      setw -g mode-keys vi
      bind-key -T copy-mode-vi v send -X begin-selection
      bind-key -T copy-mode-vi y send -X copy-selection-and-cancel

      # Reload config
      bind r source-file ~/.tmux.conf \; display "Config reloaded"

      # Split with | and -
      bind | split-window -h -c "#{pane_current_path}"
      bind - split-window -v -c "#{pane_current_path}"

      # Pane navigation (vim-style)
      bind h select-pane -L
      bind j select-pane -D
      bind k select-pane -U
      bind l select-pane -R

      ##########################################################################
      # Nord powerline status bar
      # Palette:
      #   nord0  #2E3440  nord1  #3B4252  nord2  #434C5E  nord3  #4C566A
      #   nord4  #D8DEE9  nord6  #ECEFF4
      #   nord7  #8FBCBB  nord8  #88C0D0  nord9  #81A1C1  nord10 #5E81AC
      #   nord11 #BF616A  nord13 #EBCB8B  nord14 #A3BE8C  nord15 #B48EAD
      ##########################################################################
      set -g status on
      set -g status-interval 5
      set -g status-position bottom
      set -g status-justify left

      # Colors
      set -g status-style "bg=#3B4252,fg=#D8DEE9"

      # Left: session name with powerline arrow
      set -g status-left-length 40
      set -g status-left "#[bg=#5E81AC,fg=#ECEFF4,bold] #S #[bg=#3B4252,fg=#5E81AC,nobold]"

      # Right: user@host | date/time with powerline arrows
      set -g status-right-length 80
      set -g status-right "#[fg=#4C566A,bg=#3B4252]#[fg=#D8DEE9,bg=#4C566A] #(whoami)@#H #[fg=#5E81AC,bg=#4C566A]#[fg=#ECEFF4,bg=#5E81AC,bold] %H:%M  %d %b "

      # Window list
      setw -g window-status-format         "#[fg=#81A1C1,bg=#3B4252] #I #W "
      setw -g window-status-current-format "#[fg=#3B4252,bg=#81A1C1]#[fg=#2E3440,bg=#81A1C1,bold] #I #W #[fg=#81A1C1,bg=#3B4252]"

      # Pane borders
      set -g pane-border-style        "fg=#4C566A"
      set -g pane-active-border-style "fg=#81A1C1"

      # Message / command prompt
      set -g message-style "bg=#EBCB8B,fg=#2E3440,bold"

%{ if linode_token != null && linode_token != "" ~}
  # linode-cli config (pre-seeded from var.linode_token) — deferred so user exists
  - path: /home/${username}/.config/linode-cli/cli
    owner: ${username}:${username}
    permissions: '0600'
    defer: true
    content: |
      [DEFAULT]
      default-user = devbox

      [devbox]
      token = ${linode_token}
      region = ${region}
      type = ${instance_type}
      image = ${image}
      format =
      no-headers = False
      suppress-warnings = False
%{ endif ~}

###############################################################################
# bootcmd — runs early, before package_update, on every boot
# Swap is created here so APT never runs without a safety net.
###############################################################################
bootcmd:
  # Create 4 GB swapfile before apt runs (prevents OOM during package_update
  # and Homebrew bootstrap which peaks at ~400 MB during portable-ruby install)
  - |
    if ! swapon --show | grep -q .; then
      fallocate -l 4G /swapfile || dd if=/dev/zero of=/swapfile bs=1M count=4096
      chmod 600 /swapfile
      mkswap /swapfile
      swapon /swapfile
    fi

###############################################################################
# runcmd — runs once, after packages are installed and users are created
###############################################################################
runcmd:
  # All steps run in a single bash wrapper with error trapping.
  # Using bash explicitly — cloud-init runs runcmd via /bin/sh (dash) by default,
  # which does not support pipefail or ERR traps.
  - |
    bash -euo pipefail << 'RUNCMD'
    trap 'echo "cloud-init FAILED at line $LINENO" >> /var/log/devbox-init.log; touch /var/lib/devbox-init.failed' ERR

    # Persist swap across reboots (idempotent)
    grep -qxF '/swapfile none swap sw 0 0' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab

    # Apply sysctl tuning immediately
    sysctl -p /etc/sysctl.d/99-devbox.conf

    # Restart SSH with hardened config
    systemctl restart ssh || systemctl restart sshd

    # Disable services that waste RAM/disk on a single-user dev box
    # (some may not exist on Debian — || true silences harmless failures)
    systemctl disable --now rsyslog 2>/dev/null || true
    systemctl mask \
      multipathd.service \
      multipathd.socket \
      ModemManager.service \
      systemd-networkd-wait-online.service \
      2>/dev/null || true

    # Enable earlyoom
    systemctl enable --now earlyoom

    # Generate en_US.UTF-8 locale
    locale-gen en_US.UTF-8
    update-locale LANG=en_US.UTF-8

    # Ensure home-dir subdirectories exist with correct ownership BEFORE any
    # sudo -u commands. write_files_deferred may not have created parent dirs
    # (e.g. ~/.config/linode-cli, ~/.local/bin) for the user yet.
    install -d -o ${username} -g ${username} -m 0755 \
      /home/${username}/.local \
      /home/${username}/.local/bin \
      /home/${username}/.local/state \
      /home/${username}/.config \
      /home/${username}/.zfunc

    # Install linode-cli via pipx (isolated, no system Python pollution)
    sudo -u ${username} bash -lc 'pipx ensurepath && pipx install linode-cli'

    # Install oh-my-zsh unattended (KEEP_ZSHRC=yes preserves our staged .zshrc.devbox)
    sudo -u ${username} env \
      HOME=/home/${username} \
      RUNZSH=no \
      CHSH=no \
      KEEP_ZSHRC=yes \
      sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" \
      "" --unattended

    # Clone third-party zsh plugins
    OMZ_CUSTOM="/home/${username}/.oh-my-zsh/custom/plugins"
    sudo -u ${username} git clone --depth=1 \
      https://github.com/zsh-users/zsh-autosuggestions \
      "$OMZ_CUSTOM/zsh-autosuggestions"
    sudo -u ${username} git clone --depth=1 \
      https://github.com/zsh-users/zsh-syntax-highlighting \
      "$OMZ_CUSTOM/zsh-syntax-highlighting"

    # Move staged .zshrc into place (overrides the blank one omz created)
    if [ -f /home/${username}/.zshrc.devbox ]; then
      mv /home/${username}/.zshrc.devbox /home/${username}/.zshrc
    fi

    # Install Homebrew (NONINTERACTIVE skips prompts and sudo keep-alive)
    # Requires passwordless sudo — installed via write_files sudoers drop-in above.
    sudo -u ${username} env \
      HOME=/home/${username} \
      NONINTERACTIVE=1 \
      bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    BREW=/home/linuxbrew/.linuxbrew/bin/brew

    # Pre-install brew formulae (fail-open: log errors but don't abort init)
    # These mirror the Mac daily-driver experience via brew.
    BREW_FORMULAE="bat ripgrep fd jq git-delta tree neovim tldr direnv mise zsh-completions gh kubectl opentofu"
    for formula in $BREW_FORMULAE; do
      sudo -u ${username} env HOME=/home/${username} $BREW install "$formula" \
        >> /var/log/devbox-init.log 2>&1 \
        || echo "brew install $formula FAILED (non-fatal)" >> /var/log/devbox-init.log
    done

    # Install k3s: super-tiny single-node cluster, disabled by default (RAM budget)
    # Start manually: k3s-up  |  Stop: k3s-down  |  Idle RAM cost: ~0 MB when stopped
    curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server \
      --disable traefik \
      --disable servicelb \
      --disable metrics-server \
      --disable network-policy \
      --write-kubeconfig-mode 0644 \
      --kube-apiserver-arg=default-watch-cache-size=0 \
      --kubelet-arg=image-gc-high-threshold=70 \
      --kubelet-arg=image-gc-low-threshold=50" sh - \
      >> /var/log/devbox-init.log 2>&1
    systemctl stop k3s    # don't run during cloud-init
    systemctl disable k3s # don't auto-start on boot (saves ~300 MB RAM)

    # Write zsh completions for linode-cli and gh
    sudo -u ${username} bash -lc '
      ~/.local/bin/linode-cli completion zsh > ~/.zfunc/_linode-cli 2>/dev/null || true
      /home/linuxbrew/.linuxbrew/bin/gh completion -s zsh > ~/.zfunc/_gh 2>/dev/null || true
    '

    # Fix ownership of entire home dir (belt-and-suspenders)
    chown -R ${username}:${username} /home/${username}/

    # APT cleanup
    apt-get clean
    apt-get autoremove -y

    echo "cloud-init done" >> /var/log/devbox-init.log
    touch /var/lib/devbox-init.done
    RUNCMD

final_message: "devbox cloud-init finished after $UPTIME seconds."
