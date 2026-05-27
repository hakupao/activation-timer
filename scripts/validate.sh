#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

bash -n install.sh
bash -n bin/activate-ai-window.sh
bash -n scripts/install-launchd.sh

if command -v shellcheck >/dev/null 2>&1; then
  shellcheck install.sh bin/activate-ai-window.sh scripts/install-launchd.sh
else
  echo "shellcheck not found; skipped"
fi

if command -v plutil >/dev/null 2>&1; then
  ./install.sh print-plist >/tmp/activation-timer-validate.plist
  plutil -lint /tmp/activation-timer-validate.plist >/dev/null
else
  echo "plutil not found; skipped"
fi

./install.sh dry-run >/tmp/activation-timer-dry-run.log

echo "Validation passed"

