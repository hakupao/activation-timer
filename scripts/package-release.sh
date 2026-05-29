#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${VERSION:-0.2.0}"
DIST_DIR="${ROOT_DIR}/dist"
CLI_NAME="activation-timer-cli-${VERSION}"
GUI_NAME="activation-timer-gui-${VERSION}"
APP_DIR="${DIST_DIR}/Activation Timer.app"
CLI_TARBALL="${DIST_DIR}/${CLI_NAME}.tar.gz"
GUI_ZIP="${DIST_DIR}/${GUI_NAME}.zip"
GUI_DMG="${DIST_DIR}/${GUI_NAME}.dmg"
DMG_STAGING="${DIST_DIR}/dmg-staging"

usage() {
  cat <<'USAGE'
Usage: scripts/package-release.sh [--check]

Builds two release artifacts:
  1. CLI artifact for advanced users who want the lightweight launchd scripts.
  2. GUI artifact for beginners who want the menu bar app package.
USAGE
}

required_paths=(
  "install.sh"
  ".env.example"
  "bin/activate-ai-window.sh"
  "bin/activation-state.sh"
  "scripts/install-launchd.sh"
  "app/ActivationTimerMenuBar/build-app.sh"
  "README.md"
  "README_CN.md"
  "INSTALL.md"
  "INSTALL_CN.md"
  "LICENSE"
)

check_inputs() {
  local missing=0
  local path
  for path in "${required_paths[@]}"; do
    if [[ ! -e "${ROOT_DIR}/${path}" ]]; then
      echo "Missing required release input: ${path}" >&2
      missing=1
    fi
  done

  if (( missing != 0 )); then
    return 1
  fi

  echo "CLI artifact: ${CLI_TARBALL}"
  echo "GUI artifact: ${GUI_DMG}"
  echo "GUI fallback zip: ${GUI_ZIP}"
  echo "App bundle: ${APP_DIR}"
}

build_cli_archive() {
  local staging
  staging="$(mktemp -d)"
  trap 'rm -rf "$staging"' RETURN

  local root="${staging}/${CLI_NAME}"
  mkdir -p "$root"

  cp "${ROOT_DIR}/install.sh" "$root/"
  cp "${ROOT_DIR}/.env.example" "$root/"
  cp "${ROOT_DIR}/CHANGELOG.md" "$root/"
  cp "${ROOT_DIR}/CONTRIBUTING.md" "$root/"
  cp "${ROOT_DIR}/LICENSE" "$root/"
  cp "${ROOT_DIR}/README.md" "$root/"
  cp "${ROOT_DIR}/README_CN.md" "$root/"
  cp "${ROOT_DIR}/INSTALL.md" "$root/"
  cp "${ROOT_DIR}/INSTALL_CN.md" "$root/"
  cp -R "${ROOT_DIR}/bin" "$root/bin"
  mkdir -p "$root/scripts"
  cp "${ROOT_DIR}/scripts/install-launchd.sh" "$root/scripts/"
  mkdir -p "$root/logs/raw" "$root/run" "$root/launchd"

  tar -czf "$CLI_TARBALL" -C "$staging" "$CLI_NAME"
}

build_gui_package() {
  "${ROOT_DIR}/app/ActivationTimerMenuBar/build-app.sh"

  rm -f "$GUI_ZIP" "$GUI_DMG"
  ditto -c -k --norsrc --keepParent "$APP_DIR" "$GUI_ZIP"

  if command -v hdiutil >/dev/null 2>&1; then
    rm -rf "$DMG_STAGING"
    mkdir -p "$DMG_STAGING"
    cp -R "$APP_DIR" "$DMG_STAGING/"
    ln -s /Applications "${DMG_STAGING}/Applications"
    hdiutil create \
      -volname "Activation Timer" \
      -srcfolder "$DMG_STAGING" \
      -ov \
      -format UDZO \
      "$GUI_DMG" >/dev/null
    rm -rf "$DMG_STAGING"
  else
    echo "hdiutil not found; skipped DMG and kept ${GUI_ZIP}" >&2
  fi
}

case "${1:-}" in
  --check)
    check_inputs
    ;;
  -h|--help|help)
    usage
    ;;
  "")
    check_inputs
    mkdir -p "$DIST_DIR"
    build_cli_archive
    build_gui_package
    echo "Built ${CLI_TARBALL}"
    if [[ -f "$GUI_DMG" ]]; then
      echo "Built ${GUI_DMG}"
    fi
    echo "Built ${GUI_ZIP}"
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac
