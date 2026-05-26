#!/usr/bin/env bash
set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Run as root: sudo bash deploy/google-cloud/bootstrap-vm.sh" >&2
  exit 1
fi

apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y \
  build-essential \
  ca-certificates \
  caddy \
  curl \
  git \
  libssl-dev \
  libyaml-dev \
  pkg-config \
  redis-server \
  sqlite3 \
  unzip \
  zlib1g-dev

if ! id caio >/dev/null 2>&1; then
  useradd --create-home --shell /bin/bash caio
fi

mkdir -p /srv/caio /var/lib/caio /var/lib/caio/backups /etc/caio
chown -R caio:caio /srv/caio /var/lib/caio
chmod 750 /etc/caio

if [[ -b /dev/disk/by-id/google-caio-data ]] && ! findmnt /var/lib/caio >/dev/null 2>&1; then
  if ! blkid /dev/disk/by-id/google-caio-data >/dev/null 2>&1; then
    mkfs.ext4 -F /dev/disk/by-id/google-caio-data
  fi

  echo '/dev/disk/by-id/google-caio-data /var/lib/caio ext4 defaults,nofail 0 2' >> /etc/fstab
  mount /var/lib/caio
  chown -R caio:caio /var/lib/caio
fi

sudo -iu caio bash <<'MiseInstall'
if ! command -v mise >/dev/null 2>&1; then
  curl https://mise.run | sh
  echo 'eval "$($HOME/.local/bin/mise activate bash)"' >> "$HOME/.bashrc"
fi
MiseInstall

curl -sSO https://dl.google.com/cloudagents/add-google-cloud-ops-agent-repo.sh
bash add-google-cloud-ops-agent-repo.sh --also-install
rm -f add-google-cloud-ops-agent-repo.sh

systemctl enable --now redis-server

echo "Bootstrap complete. Clone the repo into /srv/caio and configure /etc/caio/caio.env."
