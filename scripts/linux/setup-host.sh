#!/usr/bin/env bash
# Hardens and tidies a native Ubuntu Server runner host. Run as root (scripts/mac/sshsh).
# Env: LAN_CIDR (required), the network allowed to SSH in, e.g. 192.168.0.0/24.
set -euo pipefail
: "${LAN_CIDR:?set LAN_CIDR}"
export DEBIAN_FRONTEND=noninteractive

# The installer's default LVM layout uses only about half the disk.
if lvs ubuntu-vg/ubuntu-lv >/dev/null 2>&1; then lvextend -r -l +100%FREE /dev/ubuntu-vg/ubuntu-lv || true; fi

apt-get update -qq && apt-get upgrade -y -qq
apt-get install -y -qq unattended-upgrades ufw avahi-daemon >/dev/null   # avahi makes <hostname>.local resolve

# Security updates install themselves; a needed reboot happens at 04:00.
cat > /etc/apt/apt.conf.d/20auto-upgrades <<'CONF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
CONF
cat > /etc/apt/apt.conf.d/52ci-reboot <<'CONF'
Unattended-Upgrade::Automatic-Reboot "true";
Unattended-Upgrade::Automatic-Reboot-Time "04:00";
CONF

# Inbound: SSH and mDNS from the LAN only. Outbound is open (the runner needs GitHub, Docker Hub, apt).
ufw default deny incoming
ufw default allow outgoing
ufw allow from "$LAN_CIDR" to any port 22 proto tcp
ufw allow from "$LAN_CIDR" to any port 5353 proto udp
ufw --force enable

rfkill block wifi bluetooth || true
echo "Host set up. Next: scripts/linux/install-docker.sh, then register the runner."
