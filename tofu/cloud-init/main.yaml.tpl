#cloud-config

hostname: ${hostname}
fqdn: ${hostname}
preserve_hostname: false
timezone: ${timezone}

package_update: true

packages:
  - ca-certificates
  - curl
  - sudo
  - git
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

runcmd:
  - echo "127.0.1.1 ${hostname}" >> /etc/hosts
  - sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
  - systemctl restart ssh || systemctl restart sshd || true
  - |
    if ! swapon --show | grep -q .; then
      fallocate -l 2G /swapfile
      chmod 600 /swapfile
      mkswap /swapfile
      swapon /swapfile
      echo '/swapfile none swap sw 0 0' >> /etc/fstab
    fi
  - echo "cloud-init done" >> /var/log/devbox-init.log
  - touch /var/lib/devbox-init.done

final_message: "devbox cloud-init finished after $UPTIME seconds."
