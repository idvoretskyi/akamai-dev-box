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
  # Base config comes from dotfiles_repo (phase 4d); only *.local overrides here.

  - path: /home/${username}/.zshrc.local
    owner: ${username}:${username}
    permissions: '0644'
    defer: true
    content: |
      # Devbox overrides — sourced last by ~/.zshrc (dotfiles).

      # Completions installed by cloud-init
      fpath+=(~/.zfunc)
      autoload -Uz compinit && compinit -C

      command -v zoxide &>/dev/null && eval "$(zoxide init zsh --cmd z)"
      command -v direnv &>/dev/null && eval "$(direnv hook zsh)"
      command -v mise   &>/dev/null && eval "$(mise activate zsh)"

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

      # Remote clusters use ~/.kube/config; local k3s is always explicit.
      alias k3s-kubectl='sudo k3s kubectl --kubeconfig=/etc/rancher/k3s/k3s.yaml'
      alias k3s-up='sudo systemctl start k3s && echo "k3s started; run: k3s-kubectl get nodes"'
      # k3s service shutdown alone can leave workload containers running.
      alias k3s-down='sudo /usr/local/bin/k3s-killall.sh'
      alias k='kubectl'

      # opencode installs to ~/.opencode/bin
      [ -d "$HOME/.opencode/bin" ] && export PATH="$HOME/.opencode/bin:$PATH"

  - path: /home/${username}/.gitconfig.local
    owner: ${username}:${username}
    permissions: '0644'
    defer: true
    content: |
      # Machine-local git identity & signing.
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

      # SSH signing is disabled — no key on a fresh box.
      # To enable: git config --file ~/.gitconfig.local commit.gpgsign true
      #            git config --file ~/.gitconfig.local user.signingkey "key::$(head -1 ~/.ssh/authorized_keys)"
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

  - path: /home/${username}/.tmux.conf.local
    owner: ${username}:${username}
    permissions: '0644'
    defer: true
    content: |
      # Devbox override: default prefix C-b.
      set -g prefix C-b
      unbind C-a
      bind C-b send-prefix

  # Root shell: red robbyrussell-style bash prompt.
  - path: /root/.bashrc.devbox
    permissions: '0644'
    content: |
      # Red robbyrussell-style prompt — dir bold red, omz git colours.

      _devbox_git_prompt() {
        local branch dirty
        branch="$(git -C . rev-parse --abbrev-ref HEAD 2>/dev/null)" || return
        dirty="$(git -C . status --porcelain 2>/dev/null)"
        printf ' \001\033[34m\002git:(\001\033[31m\002%s\001\033[34m\002)\001\033[0m\002' "$branch"
        [ -n "$dirty" ] && printf ' \001\033[33m\002✗\001\033[0m\002'
      }

      _devbox_root_ps1() {
        local exit_code=$?
        local arrow
        if [ $exit_code -eq 0 ]; then
          arrow='\001\033[1;32m\002➜\001\033[0m\002'
        else
          arrow='\001\033[1;31m\002➜\001\033[0m\002'
        fi
        local dir='\001\033[1;31m\002\W\001\033[0m\002'
        PS1="$${arrow}  $${dir}$$(_devbox_git_prompt) "
      }

      PROMPT_COMMAND='_devbox_root_ps1'

runcmd:
  - |
    bash -euo pipefail << 'RUNCMD'
    ${indent(4, devbox_init_script)}
    RUNCMD

final_message: "devbox cloud-init finished after $UPTIME seconds."
