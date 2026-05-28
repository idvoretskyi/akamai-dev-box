#cloud-config

hostname: ${hostname}
fqdn: ${hostname}
preserve_hostname: false
manage_etc_hosts: true
timezone: ${timezone}
locale: en_US.UTF-8

package_update: true

packages:
  - ca-certificates
  - curl
  - gnupg
  - sudo
  - git
  - zsh
  - tmux
  - unzip
  - ncdu
  - rsync
  - less
  - locales
  - pipx
  - earlyoom
  - fzf
  - zoxide
  - eza
  - htop
  - build-essential
  - bat
  - ripgrep
  - fd-find
  - jq
  - git-delta
  - neovim
  - tldr
  - direnv
  - tree
  - systemd-zram-generator
%{ for p in extra_packages ~}
  - ${p}
%{ endfor ~}

users:
  - name: ${username}
    groups:
      - sudo
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/zsh
    ssh_authorized_keys: ${jsonencode(ssh_keys)}

ssh_pwauth: false

write_files:
  # ---- System-level --------------------------------------------------------
  - path: /etc/apt/apt.conf.d/99no-recommends
    content: |
      APT::Install-Recommends "false";
      APT::Install-Suggests "false";

  # VS Code apt source
  - path: /etc/apt/sources.list.d/vscode.sources
    content: |
      Types: deb
      URIs: https://packages.microsoft.com/repos/code
      Suites: stable
      Components: main
      Architectures: amd64
      Signed-By: /etc/apt/keyrings/packages.microsoft.gpg

  # GitHub CLI apt source
  - path: /etc/apt/sources.list.d/github-cli.sources
    content: |
      Types: deb
      URIs: https://cli.github.com/packages
      Suites: stable
      Components: main
      Architectures: amd64
      Signed-By: /etc/apt/keyrings/githubcli-archive-keyring.gpg

  # zram: RAM/2, zstd, high swap priority
  - path: /etc/systemd/zram-generator.conf
    content: |
      [zram0]
      zram-size = ram / 2
      compression-algorithm = zstd
      swap-priority = 100
      fs-type = swap

  - path: /etc/sysctl.d/99-devbox.conf
    content: |
      vm.swappiness = 100
      vm.vfs_cache_pressure = 50
      vm.overcommit_memory = 1
      net.core.somaxconn = 1024
      net.ipv4.tcp_fin_timeout = 15
      fs.inotify.max_user_watches = 524288

  - path: /etc/systemd/journald.conf.d/size.conf
    content: |
      [Journal]
      Storage=persistent
      Compress=yes
      SystemMaxUse=200M
      RuntimeMaxUse=50M
      ForwardToSyslog=no

  # earlyoom: protect interactive processes
  - path: /etc/default/earlyoom
    content: |
      EARLYOOM_ARGS="-r 60 -m 5 -s 5 --avoid '(^|/)(sshd|tmux|systemd|zsh)$'"

  - path: /etc/sudoers.d/90-devbox-nopasswd
    permissions: '0440'
    content: |
      %sudo ALL=(ALL) NOPASSWD:ALL

  - path: /etc/ssh/sshd_config.d/99-devbox.conf
    content: |
      PermitRootLogin no
      PasswordAuthentication no
      KbdInteractiveAuthentication no
      MaxAuthTries 3
      ClientAliveInterval 60
      ClientAliveCountMax 3

  - path: /etc/cloud/cloud.cfg.d/99-datasource.cfg
    content: |
      datasource_list: [ConfigDrive, NoCloud, None]

  # ---- User home-dir — defer: true -----------------------------------------

  - path: /home/${username}/.zshrc
    owner: ${username}:${username}
    permissions: '0644'
    defer: true
    content: |
      export PATH="$HOME/.local/bin:$PATH"

      # History
      HISTFILE=~/.zsh_history
      HISTSIZE=10000
      SAVEHIST=10000
      setopt HIST_EXPIRE_DUPS_FIRST HIST_IGNORE_DUPS HIST_REDUCE_BLANKS SHARE_HISTORY

      # Completion
      fpath+=~/.zfunc
      autoload -Uz compinit && compinit -C

      # fzf key-bindings (Ctrl-R history, Ctrl-T files)
      [ -f /usr/share/doc/fzf/examples/key-bindings.zsh ] \
        && source /usr/share/doc/fzf/examples/key-bindings.zsh

      command -v zoxide &>/dev/null && eval "$(zoxide init zsh --cmd z)"
      command -v direnv &>/dev/null && eval "$(direnv hook zsh)"
      command -v mise   &>/dev/null && eval "$(mise activate zsh)"

      # Starship prompt (Nord-themed, matches tmux bar)
      command -v starship &>/dev/null && eval "$(starship init zsh)"

      # Debian/Ubuntu package names differ from upstream — alias to expected names
      alias bat='batcat'
      alias fd='fdfind'

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

      # k3s (installed but disabled — start on demand to save RAM)
      export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
      alias k3s-up='sudo systemctl start k3s && echo "k3s started — run: kubectl get nodes"'
      alias k3s-down='sudo systemctl stop k3s && echo "k3s stopped"'
      alias k='kubectl'

      # AI: run once after SSH: claude / opencode / code tunnel / gh auth login

  - path: /home/${username}/.config/starship.toml
    owner: ${username}:${username}
    permissions: '0644'
    defer: true
    content: |
      "$schema" = 'https://starship.rs/config-schema.json'
      add_newline = false
      palette = 'nord'

      format = """
      [](fg:nord10)\
      $username\
      [](fg:nord10 bg:nord9)\
      $directory\
      [](fg:nord9 bg:nord8)\
      $git_branch\
      $git_status\
      [](fg:nord8 bg:nord1)\
      $cmd_duration\
      $status\
      [](fg:nord1)\
       $character"""

      [palettes.nord]
      nord0  = '#2E3440'
      nord1  = '#3B4252'
      nord2  = '#434C5E'
      nord3  = '#4C566A'
      nord4  = '#D8DEE9'
      nord6  = '#ECEFF4'
      nord7  = '#8FBCBB'
      nord8  = '#88C0D0'
      nord9  = '#81A1C1'
      nord10 = '#5E81AC'
      nord11 = '#BF616A'
      nord13 = '#EBCB8B'
      nord14 = '#A3BE8C'
      nord15 = '#B48EAD'

      [username]
      show_always = true
      style_user  = 'bg:nord10 fg:nord6 bold'
      style_root  = 'bg:nord11 fg:nord6 bold'
      format      = '[ $user ]($style)'

      [directory]
      style            = 'bg:nord9 fg:nord0 bold'
      format           = '[ $path ]($style)'
      truncation_length = 3
      truncate_to_repo  = true

      [git_branch]
      symbol = ''
      style  = 'bg:nord8 fg:nord0'
      format = '[ $symbol $branch ]($style)'

      [git_status]
      style  = 'bg:nord8 fg:nord0'
      format = '([$all_status$ahead_behind ]($style))'

      [cmd_duration]
      min_time = 2000
      style    = 'bg:nord1 fg:nord13'
      format   = '[ ⏱ $duration ]($style)'

      [status]
      disabled = false
      style    = 'bg:nord1 fg:nord11 bold'
      format   = '[ $symbol$status ]($style)'
      symbol   = '✗ '

      [character]
      success_symbol = '[❯](bold fg:nord14)'
      error_symbol   = '[❯](bold fg:nord11)'

      # Disable noisy modules not useful on a remote dev box
      [package]
      disabled = true
      [aws]
      disabled = true
      [gcloud]
      disabled = true
      [azure]
      disabled = true
      [battery]
      disabled = true

  - path: /home/${username}/.tmux.conf
    owner: ${username}:${username}
    permissions: '0644'
    defer: true
    content: |
      set -g default-terminal "tmux-256color"
      set -ga terminal-overrides ",*256col*:Tc"

      set -g mouse on
      set -g base-index 1
      setw -g pane-base-index 1
      set -g renumber-windows on
      set -g history-limit 5000
      set -sg escape-time 10
      set -g focus-events on

      setw -g mode-keys vi
      bind-key -T copy-mode-vi v send -X begin-selection
      bind-key -T copy-mode-vi y send -X copy-selection-and-cancel

      bind r source-file ~/.tmux.conf \; display "Config reloaded"
      bind | split-window -h -c "#{pane_current_path}"
      bind - split-window -v -c "#{pane_current_path}"
      bind h select-pane -L
      bind j select-pane -D
      bind k select-pane -U
      bind l select-pane -R

      # Nord powerline status bar
      set -g status on
      set -g status-interval 5
      set -g status-position bottom
      set -g status-justify left
      set -g status-style "bg=#3B4252,fg=#D8DEE9"

      set -g status-left-length 40
      set -g status-left "#[bg=#5E81AC,fg=#ECEFF4,bold] #S #[bg=#3B4252,fg=#5E81AC,nobold]"

      set -g status-right-length 80
      set -g status-right "#[fg=#4C566A,bg=#3B4252]#[fg=#D8DEE9,bg=#4C566A] #(whoami)@#H #[fg=#5E81AC,bg=#4C566A]#[fg=#ECEFF4,bg=#5E81AC,bold] %H:%M  %d %b "

      setw -g window-status-format         "#[fg=#81A1C1,bg=#3B4252] #I #W "
      setw -g window-status-current-format "#[fg=#3B4252,bg=#81A1C1]#[fg=#2E3440,bg=#81A1C1,bold] #I #W #[fg=#81A1C1,bg=#3B4252]"

      set -g pane-border-style        "fg=#4C566A"
      set -g pane-active-border-style "fg=#81A1C1"
      set -g message-style            "bg=#EBCB8B,fg=#2E3440,bold"

%{ if linode_token != null && linode_token != "" ~}
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

  # Root shell — red powerline bar (same structure as user, nord11 instead of nord10)
  - path: /root/.config/starship.toml
    permissions: '0644'
    content: |
      "$schema" = 'https://starship.rs/config-schema.json'
      add_newline = false
      palette = 'nord'

      format = """
      [](fg:nord11)\
      $username\
      [](fg:nord11 bg:nord9)\
      $directory\
      [](fg:nord9 bg:nord8)\
      $git_branch\
      $git_status\
      [](fg:nord8 bg:nord1)\
      $cmd_duration\
      $status\
      [](fg:nord1)\
       $character"""

      [palettes.nord]
      nord0  = '#2E3440'
      nord1  = '#3B4252'
      nord2  = '#434C5E'
      nord3  = '#4C566A'
      nord4  = '#D8DEE9'
      nord6  = '#ECEFF4'
      nord7  = '#8FBCBB'
      nord8  = '#88C0D0'
      nord9  = '#81A1C1'
      nord10 = '#5E81AC'
      nord11 = '#BF616A'
      nord13 = '#EBCB8B'
      nord14 = '#A3BE8C'
      nord15 = '#B48EAD'

      [username]
      show_always = true
      style_user  = 'bg:nord11 fg:nord6 bold'
      style_root  = 'bg:nord11 fg:nord6 bold'
      format      = '[ $user ]($style)'

      [directory]
      style            = 'bg:nord9 fg:nord0 bold'
      format           = '[ $path ]($style)'
      truncation_length = 3
      truncate_to_repo  = true

      [git_branch]
      symbol = ''
      style  = 'bg:nord8 fg:nord0'
      format = '[ $symbol $branch ]($style)'

      [git_status]
      style  = 'bg:nord8 fg:nord0'
      format = '([$all_status$ahead_behind ]($style))'

      [cmd_duration]
      min_time = 2000
      style    = 'bg:nord1 fg:nord13'
      format   = '[ ⏱ $duration ]($style)'

      [status]
      disabled = false
      style    = 'bg:nord1 fg:nord11 bold'
      format   = '[ $symbol$status ]($style)'
      symbol   = '✗ '

      [character]
      success_symbol = '[❯](bold fg:nord14)'
      error_symbol   = '[❯](bold fg:nord11)'

      # Disable noisy modules not useful on a remote dev box
      [package]
      disabled = true
      [aws]
      disabled = true
      [gcloud]
      disabled = true
      [azure]
      disabled = true
      [battery]
      disabled = true

runcmd:
  - |
    bash -euo pipefail << 'RUNCMD'
    trap 'echo "cloud-init FAILED at line $LINENO" >> /var/log/devbox-init.log; touch /var/lib/devbox-init.failed' ERR

    LOG=/var/log/devbox-init.log
    # Template variable captured once so it's a plain shell variable inside heredoc
    DEVBOX_USER='${username}'

    # Fail-open helper: label + command string, eval'd in a subshell.
    try_install() {
      local label="$1" cmd="$2"
      ( eval "$cmd" >> "$LOG" 2>&1 ) \
        || echo "$label install FAILED (non-fatal — re-run manually after SSH)" >> "$LOG"
    }

    # User-context variant.
    try_install_user() {
      local label="$1" cmd="$2"
      ( sudo -u "$DEVBOX_USER" env HOME="/home/$DEVBOX_USER" bash -c "$cmd" >> "$LOG" 2>&1 ) \
        || echo "$label install FAILED (non-fatal — re-run manually after SSH)" >> "$LOG"
    }

    # Phase 1: zram + sysctl
    systemctl daemon-reload
    systemctl start systemd-zram-setup@zram0.service \
      || echo "zram start failed — will activate on next boot" >> "$LOG"

    sysctl -p /etc/sysctl.d/99-devbox.conf

    # Phase 2: apt keys + update package index + install code + gh
    install -d -m 0755 /etc/apt/keyrings

    curl -fsSL https://packages.microsoft.com/keys/microsoft.asc \
      | gpg --dearmor -o /etc/apt/keyrings/packages.microsoft.gpg

    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
      -o /etc/apt/keyrings/githubcli-archive-keyring.gpg
    chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg

    apt-get update
    try_install "code" "apt-get install -y code"
    try_install "gh"   "apt-get install -y gh"

    # Phase 3: hardening + service cleanup
    # Enable starship for root (bash)
    grep -qxF 'eval "$(starship init bash)"' /root/.bashrc \
      || printf '\n# Starship prompt\neval "$(starship init bash)"\n' >> /root/.bashrc

    systemctl restart ssh || systemctl restart sshd

    systemctl disable --now rsyslog 2>/dev/null || true
    systemctl mask \
      multipathd.service \
      multipathd.socket \
      ModemManager.service \
      systemd-networkd-wait-online.service \
      2>/dev/null || true

    systemctl enable --now earlyoom

    locale-gen en_US.UTF-8
    update-locale LANG=en_US.UTF-8

    # Phase 4a: user home dirs + linode-cli
    install -d -o "$DEVBOX_USER" -g "$DEVBOX_USER" -m 0755 \
      "/home/$DEVBOX_USER/.local" \
      "/home/$DEVBOX_USER/.local/bin" \
      "/home/$DEVBOX_USER/.local/state" \
      "/home/$DEVBOX_USER/.config" \
      "/home/$DEVBOX_USER/.zfunc"

    # linode-cli (serial — must precede completions)
    sudo -u "$DEVBOX_USER" bash -lc 'pipx ensurepath && pipx install linode-cli'

    # Phase 4b: system installs — parallel

    # starship
    try_install "starship" \
      'curl -sS https://starship.rs/install.sh | sh -s -- --yes' &

    # kubectl
    try_install "kubectl" \
      'v="$(curl -sL https://dl.k8s.io/release/stable.txt)"
       curl -fsSL "https://dl.k8s.io/release/$v/bin/linux/amd64/kubectl" -o /tmp/kubectl
       install -m 0755 /tmp/kubectl /usr/local/bin/kubectl
       rm -f /tmp/kubectl' &

    # opentofu
    try_install "opentofu" \
      'curl -fsSL https://get.opentofu.org/install-opentofu.sh | bash -s -- --install-method standalone' &

    # k3s — installed but disabled (start with k3s-up)
    try_install "k3s" \
      "curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC='server \
        --disable traefik \
        --disable servicelb \
        --disable metrics-server \
        --disable network-policy \
        --write-kubeconfig-mode 0644 \
        --kube-apiserver-arg=default-watch-cache-size=0 \
        --kubelet-arg=image-gc-high-threshold=70 \
        --kubelet-arg=image-gc-low-threshold=50' sh -" &

    wait  # join all phase-4b background jobs
    systemctl stop    k3s 2>/dev/null || true
    systemctl disable k3s 2>/dev/null || true

    # Phase 4c: user installs — parallel

    try_install_user "mise" \
      'curl -fsSL https://mise.run | sh' &

    try_install_user "claude" \
      'curl -fsSL https://claude.ai/install.sh | bash' &

    try_install_user "opencode" \
      'curl -fsSL https://opencode.ai/install | bash' &

    wait  # join all phase-4c background jobs

    # Phase 5: zsh completions
    sudo -u "$DEVBOX_USER" bash -lc '
      command -v linode-cli >/dev/null \
        && linode-cli completion zsh > ~/.zfunc/_linode-cli 2>/dev/null || true
      command -v gh >/dev/null \
        && gh completion -s zsh > ~/.zfunc/_gh 2>/dev/null || true
    '

    # Phase 6: cleanup
    chown -R "$DEVBOX_USER":"$DEVBOX_USER" "/home/$DEVBOX_USER/"

    apt-get clean
    apt-get autoremove -y

    echo "cloud-init done" >> "$LOG"
    touch /var/lib/devbox-init.done
    RUNCMD

final_message: "devbox cloud-init finished after $UPTIME seconds."
