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
  - git-lfs
  - zsh
  - tmux
  - vim
  - wget
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
  - tealdeer
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
  # Base shell/tmux/vim/git config comes from the dotfiles repo (cloned and
  # symlinked by runcmd phase 4d). Only machine-specific overrides are written
  # here, using the *.local extension points the dotfiles already source.

  - path: /home/${username}/.zshrc.local
    owner: ${username}:${username}
    permissions: '0644'
    defer: true
    content: |
      # Devbox overrides — sourced last by ~/.zshrc (dotfiles repo).
      # Owned by cloud-init; machine-specific, not tracked in the dotfiles repo.

      # Completions installed by cloud-init (linode-cli, gh)
      fpath+=(~/.zfunc)
      autoload -Uz compinit && compinit -C

      command -v zoxide &>/dev/null && eval "$(zoxide init zsh --cmd z)"
      command -v direnv &>/dev/null && eval "$(direnv hook zsh)"
      command -v mise   &>/dev/null && eval "$(mise activate zsh)"

      # eza over ls when present
      if command -v eza &>/dev/null; then
        alias ls='eza --color=auto'
        alias ll='eza -lah --git'
        alias la='eza -lah'
      fi
      alias open='xdg-open'

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

  - path: /home/${username}/.gitconfig.local
    owner: ${username}:${username}
    permissions: '0644'
    defer: true
    content: |
      # Machine-local git identity & signing (included by the dotfiles gitconfig).
%{ if git_user_name != null || git_user_email != null ~}
      [user]
%{ if git_user_name != null ~}
          name = ${git_user_name}
%{ endif ~}
%{ if git_user_email != null ~}
          email = ${git_user_email}
%{ endif ~}
%{ else ~}
      # [user]
      #     name  = Your Name
      #     email = you@example.com
%{ endif ~}

      # The dotfiles enable SSH-format commit signing, but a fresh box has no
      # signing key — disabled here so `git commit` works out of the box.
      # To sign with your forwarded SSH agent instead:
      #   git config --file ~/.gitconfig.local user.signingkey "key::$(head -1 ~/.ssh/authorized_keys)"
      #   git config --file ~/.gitconfig.local commit.gpgsign true
      [commit]
          gpgsign = false
      [tag]
          gpgSign = false

%{ if seed_linode_cli && linode_token != null && linode_token != "" ~}
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

    sysctl -p /etc/sysctl.d/99-devbox.conf || true

    # Phase 2: apt keys + update package index + install code, gh, docker
    install -d -m 0755 /etc/apt/keyrings

    curl -fsSL https://packages.microsoft.com/keys/microsoft.asc \
      | gpg --dearmor -o /etc/apt/keyrings/packages.microsoft.gpg

    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
      -o /etc/apt/keyrings/githubcli-archive-keyring.gpg
    chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg

    # Docker CE — codename-aware deb822 source (written here, not write_files,
    # so the suite always matches the running release)
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
      | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    codename="$(. /etc/os-release && echo "$VERSION_CODENAME")"
    cat > /etc/apt/sources.list.d/docker.sources <<DOCKER
    Types: deb
    URIs: https://download.docker.com/linux/ubuntu
    Suites: $codename
    Components: stable
    Architectures: amd64
    Signed-By: /etc/apt/keyrings/docker.gpg
    DOCKER

    apt-get update || true
    try_install "code"   "apt-get install -y code"
    try_install "gh"     "apt-get install -y gh"
    try_install "docker" "apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin"

    # docker group: lets the user run docker + VS Code devcontainers over SSH
    usermod -aG docker "$DEVBOX_USER" 2>/dev/null \
      || echo "docker group add skipped (docker not installed?)" >> "$LOG"

    # Phase 3: hardening + service cleanup
    systemctl restart ssh || systemctl restart sshd

    systemctl disable --now rsyslog 2>/dev/null || true
    systemctl mask \
      multipathd.service \
      multipathd.socket \
      ModemManager.service \
      systemd-networkd-wait-online.service \
      2>/dev/null || true

    systemctl enable --now earlyoom

    locale-gen en_US.UTF-8 || true
    update-locale LANG=en_US.UTF-8 || true

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

%{ if dotfiles_repo != "" ~}
    # Phase 4d: dotfiles — base zsh/oh-my-zsh/tmux/vim/git config.
    # install.sh symlinks configs + installs oh-my-zsh; --no-packages because
    # cloud-init already installed a superset of its apt list. SHELL is set so
    # its chsh step self-skips (the user shell is already zsh via cloud-init).
    try_install_user "dotfiles" \
      'rm -rf ~/.dotfiles &&
       git clone --depth 1 ${dotfiles_repo} ~/.dotfiles &&
       cd ~/.dotfiles &&
       env SHELL="$(command -v zsh)" ./install.sh --unattended --no-packages'
%{ endif ~}

    # Phase 5: zsh completions + tealdeer cache
    sudo -u "$DEVBOX_USER" bash -lc '
      command -v linode-cli >/dev/null \
        && linode-cli completion zsh > ~/.zfunc/_linode-cli 2>/dev/null || true
      command -v gh >/dev/null \
        && gh completion -s zsh > ~/.zfunc/_gh 2>/dev/null || true
      command -v tldr >/dev/null \
        && tldr --update 2>/dev/null || true
    '

    # Phase 6: cleanup
    chown -R "$DEVBOX_USER":"$DEVBOX_USER" "/home/$DEVBOX_USER/"

    apt-get clean
    apt-get autoremove -y

    echo "cloud-init done" >> "$LOG"
    touch /var/lib/devbox-init.done
    RUNCMD

final_message: "devbox cloud-init finished after $UPTIME seconds."
