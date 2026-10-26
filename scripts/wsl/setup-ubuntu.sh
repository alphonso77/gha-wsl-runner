#!/usr/bin/env bash
# Run inside the distro as root (scripts/mac/wslsh). Creates the user and turns on systemd.
# Env: LINUX_USER (required).
set -euo pipefail
: "${LINUX_USER:?set LINUX_USER}"

id "$LINUX_USER" >/dev/null 2>&1 || useradd -m -s /bin/bash -G sudo "$LINUX_USER"
cat > /etc/wsl.conf <<CONF
[boot]
systemd=true

[user]
default=$LINUX_USER
CONF

echo "User and systemd configured. Terminate and restart the distro, then run scripts/linux/install-docker.sh."
