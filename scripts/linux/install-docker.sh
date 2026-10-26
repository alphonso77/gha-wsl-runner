#!/usr/bin/env bash
# Installs Docker Engine from Docker's apt repo on Ubuntu (native or inside WSL). Run as root.
# Env: LINUX_USER (required), the account that gets the docker group.
set -euo pipefail
: "${LINUX_USER:?set LINUX_USER}"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq ca-certificates curl >/dev/null
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
. /etc/os-release
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu ${VERSION_CODENAME} stable" > /etc/apt/sources.list.d/docker.list
apt-get update -qq
apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin >/dev/null
usermod -aG docker "$LINUX_USER"
systemctl enable --now docker
docker --version
