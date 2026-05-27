#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<'USAGE'
Usage: ./install.sh [install|check|dry-run|quota|status|run-now|uninstall|print-plist]

Default command: install

install      Install or update the macOS LaunchAgent.
check        Verify local dependencies.
dry-run      Show activation commands without sending model prompts.
quota        Query Claude/Codex quota status without sending model prompts.
status       Show LaunchAgent status.
run-now      Trigger the installed LaunchAgent once. This sends model prompts.
uninstall    Unload and remove the LaunchAgent.
print-plist  Print the generated launchd plist.
USAGE
}

cmd="${1:-install}"

case "$cmd" in
  install)
    "${ROOT_DIR}/scripts/install-launchd.sh" install
    ;;
  check)
    "${ROOT_DIR}/bin/activate-ai-window.sh" --check
    ;;
  dry-run)
    "${ROOT_DIR}/bin/activate-ai-window.sh" --dry-run
    ;;
  quota)
    "${ROOT_DIR}/bin/activate-ai-window.sh" --status
    ;;
  status)
    "${ROOT_DIR}/scripts/install-launchd.sh" status
    ;;
  run-now)
    "${ROOT_DIR}/scripts/install-launchd.sh" run-now
    ;;
  uninstall)
    "${ROOT_DIR}/scripts/install-launchd.sh" uninstall
    ;;
  print-plist)
    "${ROOT_DIR}/scripts/install-launchd.sh" print-plist
    ;;
  -h|--help|help)
    usage
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac

