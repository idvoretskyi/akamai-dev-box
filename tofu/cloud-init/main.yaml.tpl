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
      INSTALL_SHELL_STACK=${install_shell}
      EXTRA_PACKAGES="${join(" ", extra_packages)}"

runcmd:
  - echo "127.0.1.1 ${hostname}" >> /etc/hosts
  - sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
  - systemctl restart ssh || systemctl restart sshd || true
  - mkdir -p /opt/devbox/scripts /var/log /var/lib
  - |
    set -e
    BASE="https://raw.githubusercontent.com/idvoretskyi/akamai-dev-box/${git_ref}/tofu/cloud-init/scripts"
    for s in 10-base.sh 20-docker.sh 30-k3s.sh 40-kube-tools.sh 50-langs.sh 60-agents.sh 70-vscode-tunnel.sh 80-shell.sh; do
      curl -fsSL "$BASE/$s" -o "/opt/devbox/scripts/$s"
      chmod 0755 "/opt/devbox/scripts/$s"
    done
  - bash -c 'set -o pipefail; { for s in 10-base.sh 20-docker.sh 30-k3s.sh 40-kube-tools.sh 50-langs.sh 60-agents.sh 70-vscode-tunnel.sh 80-shell.sh; do /opt/devbox/scripts/$s || exit 1; done && touch /var/lib/devbox-init.done; } 2>&1 | tee -a /var/log/devbox-init.log || touch /var/lib/devbox-init.failed'

final_message: "devbox cloud-init finished after $UPTIME seconds. See /var/log/devbox-init.log."
