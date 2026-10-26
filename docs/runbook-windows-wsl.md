# Runbook: Windows + WSL2 runner

For a native Linux box, use [`runbook-linux.md`](runbook-linux.md) instead; it's shorter and has none of Windows' quirks. Choose this one only if the box has to stay on Windows.

About half a day, most of it waiting on downloads and Windows Update. Commands run from the repo root on your Mac/Linux machine unless marked **at the box**. `<host>` is the SSH alias you give the box; `<winuser>` is its Windows account; `<linuxuser>` the account inside Ubuntu.

Needs: a Windows 11 **Pro** mini PC (Home lacks Remote Desktop and some policies), 16 GB+ RAM, wired Ethernet (Cat5e or better: plain Cat5 links at 100 Mbps), a monitor and keyboard for the first hour, `gh` logged in as an admin of the target repo, and a router where you can reserve an IP.

## 1. Windows setup (at the box)

1. Run Windows setup. A **local** account keeps the username what you typed (a Microsoft account can shorten it, e.g. `jonathan` to `jonat`). Windows 11 hides the local-account option; Shift+F10 at the network screen, then `start ms-cxh:localonly` (older builds: `OOBE\BYPASSNRO`).
2. Connect Ethernet. Run Windows Update once from Settings and restart; a pending update can stall the OpenSSH install in step 2.
3. **BIOS** (tap Del or F2 at power-on; key varies): set *Power Loss Policy* (a.k.a. Restore on AC Power Loss) to **Always On**, so the box returns after a power cut. Optionally cut the integrated-graphics memory (UMA) to the minimum; the box is headless. If you can't catch the key in time, `reagentc /boottore && shutdown /r /t 0` from an admin prompt reboots into the recovery menu, which offers firmware settings. (The flag stays armed if you enter the BIOS by keypress instead.)
4. **Admin PowerShell** (not Windows PowerShell ISE). Fetch and read the script before running it:
   ```powershell
   irm https://raw.githubusercontent.com/alphonso77/gha-wsl-runner/main/scripts/windows/bootstrap.ps1 -OutFile bootstrap.ps1
   notepad bootstrap.ps1
   .\bootstrap.ps1 -KeysUrl https://github.com/<you>.keys -NewName <PCNAME> -DisableWifi
   ```
   It does power settings, OpenSSH, your keys, Remote Desktop, clock sync, update policy, and prints the IPv4 address. Restart if you renamed the PC.

## 2. Reach it (on your machine)

1. Reserve the box's IP in the router (DHCP reservation by Ethernet MAC) so the address never moves.
2. Add to `~/.ssh/config`:
   ```
   Host <host>
     HostName <pcname>.local
     User <winuser>
   ```
   First connect: `ssh -o StrictHostKeyChecking=accept-new <host> hostname`. Test the port with `nc -z -G 3 <pcname>.local 22` (Windows drops ping).
3. Unplug the monitor and keyboard whenever you like; from here it's all SSH.

## 3. Windows Update, as SYSTEM

```bash
scripts/mac/winps <host> scripts/windows/install-updates.ps1
until ssh <host> 'type C:\ProgramData\gar\wu.log' 2>/dev/null | tr -d '\000\r' | grep -q '^done'; do sleep 10; done
ssh <host> 'type C:\ProgramData\gar\wu.log'
ssh <host> 'schtasks /Delete /TN "gar install updates" /F'
```
Restart (`ssh <host> 'shutdown /r /t 0'`) if the log says a reboot is required. Don't leave this task in place.

## 4. WSL2 and Ubuntu

```bash
scripts/mac/winps <host> scripts/windows/wsl-install.ps1 '-Stage 1'
ssh <host> 'shutdown /r /t 0'          # back in under a minute
scripts/mac/winps <host> scripts/windows/wsl-install.ps1 '-Stage 2'      # slow: Ubuntu image ~0.5 MB/s
scripts/mac/wslsh <host> scripts/wsl/setup-ubuntu.sh LINUX_USER=<linuxuser>
ssh <host> 'wsl --terminate Ubuntu-24.04'          # restart so systemd takes over
scripts/mac/wslsh <host> scripts/linux/install-docker.sh LINUX_USER=<linuxuser>
scripts/mac/wslsh <host> <(echo 'systemctl is-system-running; docker run --rm hello-world | head -3')
```
The last line should say `running` and print Docker's greeting. Set the Linux user's password by hand if you want sudo to work interactively: `ssh -t <host> wsl -u root passwd <linuxuser>`.

## 5. Survive reboots

```bash
scripts/mac/winps <host> scripts/windows/keepalive.ps1
```
Check the Windows clock before registering anything: `ssh <host> 'w32tm /query /status'` must show a real time source (not "Local CMOS Clock") and Leap Indicator 0. See `gotchas.md`.

## 6. Register the runner

```bash
scripts/mac/register-runner.sh <host> <owner>/<repo> <runner-name> <linuxuser>
```
Prints `<name> online self-hosted,Linux,X64,wsl`. A runner's name can't be changed after registration, so use the final one (`gar1`, `gar2`, ...). Use one runner per host.

Point the workflow at it with a repo variable you flip by hand:
```yaml
runs-on: ${{ vars.RUNNER || 'ubuntu-latest' }}   # variable RUNNER=self-hosted to use the box; delete it to go back
```
Run a real workflow, ideally one with Docker and timing-sensitive tests.

## 7. Final test

```bash
ssh <host> 'shutdown /r /t 0'
until nc -z -G 2 <pcname>.local 22; do sleep 5; done      # SSH back in ~30 s
ssh <host> quser                                          # "No User exists" = nobody is logged in
ssh <host> 'wsl -l -v' | tr -d '\000'                     # Ubuntu-24.04 Running
gh api repos/<owner>/<repo>/actions/runners --jq '.runners[] | "\(.name) \(.status)"'   # online, ~2.5 min after boot
```
Then unplug power, plug it back in, and repeat the check. That's the Always On BIOS setting earning its keep.

## Planned downtime

```bash
ssh <host> 'wsl -d Ubuntu-24.04 -u root -- systemctl stop actions.runner.* docker.service docker.socket'
ssh <host> 'shutdown /s /t 0'
```
Set the `RUNNER` variable back to `ubuntu-latest` first (or delete it) so queued jobs don't wait for a box that's off.
