#cloud-config

# Keep packages up to date on first boot
package_update: true
package_upgrade: true

# Install common development tools
packages:
  - git
  - curl
  - wget
  - unzip
  - jq
  - htop
  - tmux
  - build-essential
  - ca-certificates

users:
  - name: ${username}
    groups:
      - sudo
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    ssh_authorized_keys: ${jsonencode(ssh_keys)}

# Harden SSH configuration
ssh_pwauth: false

runcmd:
  - sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
  - systemctl restart sshd
