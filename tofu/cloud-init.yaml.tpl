#cloud-config
users:
  - name: ${username}
    groups:
      - sudo
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    ssh_authorized_keys: ${jsonencode(ssh_keys)}

ssh_pwauth: false
