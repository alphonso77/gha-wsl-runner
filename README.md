# gha-wsl-runner

Turn a mini PC into a headless, self-hosted GitHub Actions runner for Linux jobs: Docker Engine, a systemd runner service, and a setup that comes back by itself after a power cut or reboot with nobody logged in. Two paths:

- **Native Ubuntu Server** ([`docs/runbook-linux.md`](docs/runbook-linux.md)). Recommended: about an hour, plain bash over SSH.
- **Windows 11 + WSL2** ([`docs/runbook-windows-wsl.md`](docs/runbook-windows-wsl.md)). For a box that must stay on Windows. Works, but most of the effort goes into keeping WSL alive and Windows quiet.

Built while standing up two runners for [Fratelli Software](https://fratellisoftware.com). The first, `gar1`, ran the Windows + WSL2 path from 2026-10-22.

**Status:** the Windows + WSL2 steps come from commands that ran on a real box, except the power settings, BIOS step and OpenSSH install, which are written from documentation. The native Linux path is untested until `gar2` (the first box built that way) is done; this line changes when it is. The scripts in `scripts/` are those commands tidied into parameters; 

## The shape of it

You touch the box with a keyboard once (Windows setup, one admin PowerShell paste). Everything after that is driven over SSH from a Mac or Linux machine.

| Path | What |
|---|---|
| [`docs/runbook-linux.md`](docs/runbook-linux.md), [`runbook-windows-wsl.md`](docs/runbook-windows-wsl.md) | The steps, in order. Start with one of these. |
| [`docs/gotchas.md`](docs/gotchas.md) | What failed and why. Read before improvising. |
| `scripts/linux/` | Bash for any Ubuntu (native or WSL): host setup, Docker, runner install. |
| `scripts/windows/`, `scripts/wsl/` | The Windows + WSL2 path only: PowerShell for the PC, user + systemd inside WSL. |
| `scripts/mac/` | Helpers that send those scripts over SSH (`sshsh` for native Linux; `winps` and `wslsh` dodge cmd.exe quoting on Windows). |

## Choices worth knowing

- **Native Linux if you can.** WSL2 adds a keep-alive task, a second clock to drift, Windows Update to tame and cmd.exe quoting to fight, for jobs that never needed Windows. Docker Engine, never Docker Desktop.
- **One runner per host.** Two runners on one box fight over the same Docker daemon and ports.
- **No auto-fallback.** The workflow picks its runner from a repo variable (`runs-on: ${{ vars.RUNNER || 'ubuntu-latest' }}`); a human flips it. A dead runner means queued jobs until you flip it back.
- **Private repos only.** A self-hosted runner executes whatever a workflow sends it. Never attach one to a public repo that accepts fork PRs.
