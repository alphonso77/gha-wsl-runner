#!/usr/bin/env bash
# Register a runner for a repo and install it on the box (in its WSL, or natively). Needs `gh` logged in as a repo admin.
#   [TARGET=linux] register-runner.sh <ssh-host> <owner/repo> <runner-name> <linux-user> [extra-labels]
# TARGET=linux for a native Linux box (default is a Windows box running WSL).
# Runner names cannot be changed later, so pick the final one (gar1, gar2, ...).
set -euo pipefail
host=${1:?}; repo=${2:?}; name=${3:?}; user=${4:?}; here=$(cd "$(dirname "$0")" && pwd)
case "${TARGET:-wsl}" in linux) run=sshsh ;; wsl) run=wslsh ;; *) echo "TARGET must be linux or wsl" >&2; exit 1 ;; esac
labels=${5:-$([ "${TARGET:-wsl}" = linux ] && echo native || echo wsl)}   # extra label beyond self-hosted,Linux,X64
token=$(gh api -X POST "repos/$repo/actions/runners/registration-token" --jq .token)
"$here/$run" "$host" "$here/../linux/install-runner.sh" \
  LINUX_USER="$user" RUNNER_URL="https://github.com/$repo" RUNNER_TOKEN="$token" RUNNER_NAME="$name" RUNNER_LABELS="$labels"
gh api "repos/$repo/actions/runners" --jq ".runners[] | select(.name==\"$name\") | \"\(.name) \(.status) \([.labels[].name] | join(\",\"))\""
