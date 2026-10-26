#!/usr/bin/env bash
# Run inside the distro as root (scripts/mac/wslsh). Creates the user, turns on systemd, installs Docker Engine.
# Env: LINUX_USER (required). After it finishes: wsl --terminate <distro>, then start it again so systemd takes over.
set -euo pipefail
: "${LINUX_USER:?set LINUX_USER}"
export DEBIAN_FRONTEND=noninteractive

id "$LINUX_USER" >/dev/null 2>&1 || useradd -m -s /bin/bash -G sudo "$LINUX_USER"
cat > /etc/wsl.conf <<CONF
[boot]
systemd=true

[user]
default=$LINUX_USER
CONF

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
echo "Installed. Terminate and restart the distro, then check: systemctl is-system-running; docker run --rm hello-world"
