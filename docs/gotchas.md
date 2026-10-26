# Gotchas

What went wrong building the first runner, and the cause where we measured it.

## Over SSH

- **The remote shell is cmd.exe.** `|`, `(` and `)` in a command string break it (`'grep' is not recognized`). Send PowerShell as `-EncodedCommand` (UTF-16LE base64) and WSL scripts as a base64 blob; `scripts/mac/winps` and `wslsh` do both. The command line caps at ~8191 characters, so keep scripts short or write the file to disk first.
- **`wsl.exe` prints UTF-16.** Pipe its output through `tr -d '\000\r'`.
- **PowerShell over SSH appends a `#< CLIXML` progress blob.** Filter lines starting `<` or `#<`.
- **`ssh -o BatchMode=yes` on a new host fails with "Host key verification failed"** until you connect once with `-o StrictHostKeyChecking=accept-new`.
- **SSH hangs (no refusal) on a Windows box with a Public network profile.** The OpenSSH firewall rule only covers Private. Set the Ethernet profile to Private: `Set-NetConnectionProfile -InterfaceAlias Ethernet -NetworkCategory Private`.
- **Admin accounts use `C:\ProgramData\ssh\administrators_authorized_keys`**, not `~\.ssh\authorized_keys`. Its ACL must be SYSTEM + Administrators only or sshd ignores it.
- **Password login uses the account password, not the Windows Hello PIN.** And a Microsoft account's SSH username is its shortened local name.
- **The "no post-quantum key exchange" warning** comes from the in-box `OpenSSH_for_Windows_9.5`. Harmless on a LAN; the separate Win32-OpenSSH builds from 10.0.0.0p2 fix it.

## Installing things remotely

- **`wsl --install`, `wsl --update` and winget fail or hang over SSH** (winget: `0x8a15000f`; the inbox `wsl.exe` just says WSL isn't installed). The working path is two Windows features, a restart, the signed MSI from github.com/microsoft/WSL, then `wsl --install --from-file <.wsl> --name Ubuntu-24.04 --no-launch`.
- **releases.ubuntu.com is slow** (~0.5 MB/s from two different machines); GitHub downloads ran ~490 Mbps. Not the box.
- **Windows Update's COM API is denied in an SSH session.** Run it as SYSTEM through a one-shot scheduled task (`install-updates.ps1`).
- **`shutdown /r /fw` (error 203) and `/o` (error 87) don't work from a remote session.** `reagentc /boottore` does, once.

## Staying up

- **WSL stops an idle distro**, taking Docker and the runner with it. A startup task running `wsl.exe ... -- sleep infinity` as an S4U principal keeps it up at boot with nobody logged in and no stored password.
- **An unsynced Windows clock makes the WSL clock flip by the offset every 5 seconds** (measured: +/-300 s, `Clock change detected` in `journalctl`). It failed two timing-based integration tests on the first CI run. Windows Time was on a delayed start and reading "Local CMOS Clock"; fix is `w32time` Automatic, an explicit NTP peer, hourly polling, plus a boot-time resync task (`bootstrap.ps1`). The mechanism (WSL host sync fighting systemd-timesyncd) is our inference; the measurement is solid. After a cold boot Windows still hadn't synced on its own, hence the boot task; whether that task fires correctly on a cold boot is unverified.
- **Update active hours default to overnight**, which is backwards for a CI box that is busy in the day. `bootstrap.ps1` sets 07:00-23:00 and no restart while a user is signed in.
- **WSL gets half the RAM by default** (~15 GB of 32). Add a `%UserProfile%\.wslconfig` if jobs need more.

## Runner

- **`--labels wsl` adds to the defaults**, giving `self-hosted, Linux, X64, wsl`.
- **Runner names can't be changed**, and `config.sh --replace` only replaces a runner with the same name.
- **Registration tokens are single-use and expire in an hour.** Fetch one with `gh api -X POST repos/<o>/<r>/actions/runners/registration-token --jq .token` and don't echo it.
- **Never attach a self-hosted runner to a public repo that accepts fork PRs.**
