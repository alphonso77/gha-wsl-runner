#!/usr/bin/env bash
# Run inside the distro as root (scripts/mac/register-runner.sh does this). Installs the latest runner as a systemd service.
# Env: LINUX_USER, RUNNER_URL (https://github.com/<owner>/<repo>), RUNNER_TOKEN (single use, ~1 h), RUNNER_NAME, RUNNER_LABELS (extra, optional)
set -euo pipefail
: "${LINUX_USER:?}" "${RUNNER_URL:?}" "${RUNNER_TOKEN:?}" "${RUNNER_NAME:?}"

rel=$(curl -fsSL https://api.github.com/repos/actions/runner/releases/latest)
V=$(printf '%s' "$rel" | grep -m1 '"tag_name"' | sed -E 's/.*"v([0-9.]+)".*/\1/')
SHA=$(printf '%s' "$rel" | grep -oE 'BEGIN SHA linux-x64 -->[a-f0-9]{64}' | head -1 | grep -oE '[a-f0-9]{64}')
[ -n "$V" ] && [ -n "$SHA" ] || { echo "could not read runner version/sha from the release" >&2; exit 1; }

sudo -u "$LINUX_USER" env V="$V" SHA="$SHA" RUNNER_URL="$RUNNER_URL" RUNNER_TOKEN="$RUNNER_TOKEN" RUNNER_NAME="$RUNNER_NAME" RUNNER_LABELS="${RUNNER_LABELS:-wsl}" bash -c '
set -euo pipefail
mkdir -p ~/actions-runner && cd ~/actions-runner
curl -fsSLo runner.tar.gz "https://github.com/actions/runner/releases/download/v$V/actions-runner-linux-x64-$V.tar.gz"
echo "$SHA  runner.tar.gz" | sha256sum -c -
tar xzf runner.tar.gz && rm runner.tar.gz
./config.sh --unattended --url "$RUNNER_URL" --token "$RUNNER_TOKEN" --name "$RUNNER_NAME" --labels "$RUNNER_LABELS" --work _work --replace
'
cd "/home/$LINUX_USER/actions-runner"
./bin/installdependencies.sh >/dev/null 2>&1 || true
./svc.sh install "$LINUX_USER"
./svc.sh start
systemctl is-active "actions.runner.*"
