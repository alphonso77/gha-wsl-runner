#!/usr/bin/env bash
# Register a runner for a repo and install it in the box's WSL. Needs `gh` logged in as a repo admin.
#   register-runner.sh <ssh-host> <owner/repo> <runner-name> <linux-user> [extra-labels]
# Runner names cannot be changed later, so pick the final one (gar1, gar2, ...).
set -euo pipefail
host=${1:?}; repo=${2:?}; name=${3:?}; user=${4:?}; labels=${5:-wsl}
here=$(cd "$(dirname "$0")" && pwd)
token=$(gh api -X POST "repos/$repo/actions/runners/registration-token" --jq .token)
"$here/wslsh" "$host" "$here/../wsl/install-runner.sh" \
  LINUX_USER="$user" RUNNER_URL="https://github.com/$repo" RUNNER_TOKEN="$token" RUNNER_NAME="$name" RUNNER_LABELS="$labels"
gh api "repos/$repo/actions/runners" --jq ".runners[] | select(.name==\"$name\") | \"\(.name) \(.status) \([.labels[].name] | join(\",\"))\""
