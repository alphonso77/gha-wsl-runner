# gha-wsl-runner

Turn a Windows 11 mini PC into a headless, self-hosted GitHub Actions runner: WSL2 Ubuntu 24.04, Docker Engine, a systemd runner service, and a setup that comes back by itself after a power cut or reboot with nobody logged in.

Linux jobs only (the runner lives in WSL2). Built while standing up two runners for [Fratelli Software](https://fratellisoftware.com). The first, `gar1`, ran this way from 2026-10-22.

**Status:** most steps come from commands that ran on a real box; the power settings, BIOS step and OpenSSH install were done by hand and are written from documentation. The scripts in `scripts/` are those commands tidied into parameters; the second build (`gar2`) is their first run, so treat them as unproven until `docs/runbook.md` says otherwise.

## The shape of it

You touch the box with a keyboard once (Windows setup, one admin PowerShell paste). Everything after that is driven over SSH from a Mac or Linux machine.

| Path | What |
|---|---|
| [`docs/runbook.md`](docs/runbook.md) | The steps, in order. Start here. |
| [`docs/gotchas.md`](docs/gotchas.md) | What failed and why. Read before improvising. |
| `scripts/windows/` | PowerShell run on the mini PC (bootstrap, WSL install, keep-alive task, Windows Update). |
| `scripts/wsl/` | Bash run inside Ubuntu (user + systemd + Docker, runner install). |
| `scripts/mac/` | Helpers that send those scripts over SSH, dodging cmd.exe quoting. |

## Choices worth knowing

- **WSL2, not Docker Desktop and not a Linux install.** Windows stays usable for the vendor's drivers and BIOS updates; Docker Engine runs under WSL's systemd.
- **One runner per host.** Two runners on one box fight over the same Docker daemon and ports.
- **No auto-fallback.** The workflow picks its runner from a repo variable (`runs-on: ${{ vars.RUNNER || 'ubuntu-latest' }}`); a human flips it. A dead runner means queued jobs until you flip it back.
- **Private repos only.** A self-hosted runner executes whatever a workflow sends it. Never attach one to a public repo that accepts fork PRs.
