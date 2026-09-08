#!/usr/bin/env bash
# Rendered via templatefile() from tofu/main.tf and embedded into cloud-init
# user-data (see cloud-init/main.yaml.tpl). Runs as root on first boot.
set -euo pipefail

trap 'echo "cloud-init FAILED at line $LINENO" >> /var/log/devbox-init.log; touch /var/lib/devbox-init.failed' ERR

LOG=/var/log/devbox-init.log
DEVBOX_USER='${username}'

# Fail-open helper: label + command, eval'd in a subshell.
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

# Docker CE — codename-aware deb822 source
curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg
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

# non-root docker access
usermod -aG docker "$DEVBOX_USER" 2>/dev/null \
  || echo "docker group add skipped (docker not installed?)" >> "$LOG"

# Phase 3: hardening + service cleanup
grep -qxF '[ -f ~/.bashrc.devbox ]' /root/.bashrc \
  || printf '\n# Devbox red prompt\n[ -f ~/.bashrc.devbox ] && . ~/.bashrc.devbox\n' >> /root/.bashrc

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
  "curl -sfL https://get.k3s.io | INSTALL_K3S_SKIP_START=true INSTALL_K3S_SKIP_ENABLE=true INSTALL_K3S_EXEC='server \
    --disable traefik \
    --disable servicelb \
    --disable metrics-server \
    --disable network-policy \
    --write-kubeconfig-mode 0600 \
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
# Phase 4d: dotfiles — installs oh-my-zsh + symlinks; --no-packages skips
# apt (cloud-init already covers it); SHELL preset avoids a chsh prompt.
try_install_user "dotfiles" \
  'rm -rf ~/.dotfiles &&
   git clone --depth 1 "${dotfiles_repo}" ~/.dotfiles &&
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
