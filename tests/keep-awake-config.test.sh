#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if KEEP_AWAKE_MODE=banana "$ROOT_DIR/bin/activate-ai-window.sh" --dry-run >/tmp/stoker-keep-awake-mode.log 2>&1; then
  echo "expected invalid KEEP_AWAKE_MODE to fail" >&2
  exit 1
fi

grep -q 'KEEP_AWAKE_MODE must be off, during, or always' /tmp/stoker-keep-awake-mode.log

if KEEP_AWAKE_SECONDS=abc "$ROOT_DIR/bin/activate-ai-window.sh" --dry-run >/tmp/stoker-keep-awake-seconds.log 2>&1; then
  echo "expected invalid KEEP_AWAKE_SECONDS to fail" >&2
  exit 1
fi

grep -q 'KEEP_AWAKE_SECONDS must be a positive integer' /tmp/stoker-keep-awake-seconds.log

echo "keep-awake config test passed"
