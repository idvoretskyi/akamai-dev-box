#cloud-config

hostname: ${hostname}
fqdn: ${hostname}
preserve_hostname: false
timezone: ${timezone}

package_update: true
package_upgrade: true

packages:
  - ca-certificates
  - curl
  - gnupg
  - lsb-release
  - sudo
  - git
  - jq
  - tmux
  - htop
  - unzip
%{ for p in extra_packages ~}
  - ${p}
%{ endfor ~}

users:
  - name: ${username}
    groups:
      - sudo
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    ssh_authorized_keys: ${jsonencode(ssh_keys)}

ssh_pwauth: false

write_files:
  - path: /etc/devbox/env
    permissions: "0644"
    content: |
      DEVBOX_USER=${username}
      INSTALL_DOCKER=${install_docker}
      INSTALL_K3S=${install_k3s}
      K3S_CHANNEL=${k3s_channel}
      K3S_DISABLE="${join(" ", k3s_disable)}"
      INSTALL_LANGUAGES="${join(" ", install_languages)}"
      INSTALL_CLAUDE_CODE=${install_claude}
      INSTALL_OPENCODE=${install_opencode}
      INSTALL_VSCODE_TUNNEL=${install_vscode}
      VSCODE_TUNNEL_NAME=${vscode_tunnel_name}
      EXTRA_PACKAGES="${join(" ", extra_packages)}"
%{ for name in scripts ~}
  - path: /opt/devbox/scripts/${name}
    permissions: "0755"
    content: |
${indent(6, script_files[name])}
%{ endfor ~}

runcmd:
  - sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
  - systemctl restart ssh || systemctl restart sshd || true
  - mkdir -p /var/log /var/lib
  - bash -c 'set -o pipefail; { %{ for name in scripts ~}/opt/devbox/scripts/${name} && %{ endfor ~}touch /var/lib/devbox-init.done; } 2>&1 | tee -a /var/log/devbox-init.log || touch /var/lib/devbox-init.failed'

final_message: "devbox cloud-init finished after $UPTIME seconds. See /var/log/devbox-init.log."
