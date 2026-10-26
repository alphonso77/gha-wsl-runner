# Runbook: native Ubuntu Server runner

About an hour. No Windows, no WSL, no cmd.exe quoting: plain bash over SSH. `<host>` is the SSH alias you give the box, `<user>` its Linux account, `<lan>` your network (e.g. `192.168.0.0/24`).

Needs: a mini PC with wired Ethernet, a USB stick (8 GB+), a monitor and keyboard for the install, `gh` logged in as an admin of the target repo, and a router where you can reserve an IP.

## 1. Before you wipe the disk

- If the vendor ships BIOS updates as a Windows tool and you want a newer one, boot the factory Windows once and flash it now. Skip this if you don't care.
- Write the USB: download the **Ubuntu Server 24.04 LTS** ISO from ubuntu.com, check its SHA256 against the published list, then `sudo dd if=ubuntu-24.04-live-server-amd64.iso of=/dev/rdiskN bs=4m` (macOS; find N with `diskutil list`, unmount first) or use balenaEtcher.

## 2. BIOS and install (at the box)

1. In the BIOS (Del or F2; the one-time boot menu is often F7): set *Power Loss Policy* to **Always On**, leave **Secure Boot on** (Ubuntu boots under it), set a BIOS admin password, and turn off Wi-Fi and Bluetooth if you won't use them.
2. Boot the USB and run the installer: minimal server, wired network via DHCP, whole disk (the default LVM layout is fine; step 4 grows it), your hostname and user, **Install OpenSSH server**, and *Import SSH identity* from GitHub (`gh:<you>`). That imports **every** key on the account; remove the ones you don't want from `~/.ssh/authorized_keys` afterwards. Untick password authentication over SSH.
3. Reboot, remove the USB, note the IP the installer shows.

## 3. Reach it (on your machine)

1. Reserve the IP in the router (DHCP reservation by Ethernet MAC).
2. `~/.ssh/config`:
   ```
   Host <host>
     HostName <hostname>.local
     User <user>
   ```
   `<hostname>.local` only resolves after step 4 installs avahi; use the IP until then. First connect: `ssh -o StrictHostKeyChecking=accept-new <host> hostname`.
3. Passwordless sudo, so the scripts can run as root. Be aware that the runner user is in the `docker` group, which is root-equivalent anyway:
   ```bash
   ssh -t <host> "echo '<user> ALL=(ALL) NOPASSWD:ALL' | sudo tee /etc/sudoers.d/90-ci && sudo chmod 440 /etc/sudoers.d/90-ci"
   ```
4. Unplug the monitor and keyboard.

## 4. Host setup and Docker

```bash
scripts/mac/sshsh <host> scripts/linux/setup-host.sh LAN_CIDR=<lan>
scripts/mac/sshsh <host> scripts/linux/install-docker.sh LINUX_USER=<user>
ssh <host> 'timedatectl | grep synchronized; df -h /; sudo -u <user> docker run --rm hello-world | head -3'
```
`setup-host.sh` grows the disk to its full size, turns on automatic security updates (a reboot, if needed, happens at 04:00), installs a firewall that allows SSH and mDNS from your LAN only, and blocks Wi-Fi and Bluetooth. The check should print `System clock synchronized: yes`, a full-size disk, and Docker's greeting.

## 5. Register the runner

```bash
TARGET=linux scripts/mac/register-runner.sh <host> <owner>/<repo> <runner-name> <user>
```
Prints `<name> online self-hosted,Linux,X64,native`. A runner's name can't be changed after registration, so use the final one. One runner per host.

Point the workflow at it with a repo variable you flip by hand:
```yaml
runs-on: ${{ vars.RUNNER || 'ubuntu-latest' }}   # RUNNER=self-hosted uses the box; delete it to go back
```
If two self-hosted runners exist, `self-hosted` matches either; add the runner's label to target one.

## 6. Final test

```bash
ssh <host> 'sudo reboot'
until nc -z -G 2 <hostname>.local 22; do sleep 5; done
gh api repos/<owner>/<repo>/actions/runners --jq '.runners[] | "\(.name) \(.status)"'    # online within a minute or two
```
Then pull the power and plug it back in and repeat the check. That is the *Always On* BIOS setting earning its keep.

## Planned downtime

Set the `RUNNER` variable to `ubuntu-latest` (or delete it) first, then `ssh <host> 'sudo systemctl stop actions.runner.* && sudo poweroff'`.
