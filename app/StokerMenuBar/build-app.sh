#!/usr/bin/env bash
set -euo pipefail

PACKAGE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${PACKAGE_DIR}/../.." && pwd)"
APP_DIR="${ROOT_DIR}/dist/Stoker.app"
EXECUTABLE="${PACKAGE_DIR}/.build/release/StokerMenuBar"
ENGINE_DIR="${APP_DIR}/Contents/Resources/stoker"
ICON_DIR="${APP_DIR}/Contents/Resources"

cd "$PACKAGE_DIR"
swift build -c release

rm -rf "$APP_DIR"
mkdir -p "${APP_DIR}/Contents/MacOS" "$ENGINE_DIR"
cp "$EXECUTABLE" "${APP_DIR}/Contents/MacOS/StokerMenuBar"
"${ROOT_DIR}/scripts/generate-app-icon.sh" "$ICON_DIR"
cp "${ICON_DIR}/icon_512x512@2x.png" "${ROOT_DIR}/dist/AppIcon-preview.png"
rm -rf "${ICON_DIR}/AppIcon.iconset" "${ICON_DIR}/icon_512x512@2x.png"

copy_path() {
  local source="$1"
  local destination="$2"
  if [[ -e "$source" ]]; then
    mkdir -p "$(dirname "$destination")"
    cp -R "$source" "$destination"
  fi
}

copy_path "${ROOT_DIR}/install.sh" "${ENGINE_DIR}/install.sh"
copy_path "${ROOT_DIR}/.env.example" "${ENGINE_DIR}/.env.example"
copy_path "${ROOT_DIR}/README.md" "${ENGINE_DIR}/README.md"
copy_path "${ROOT_DIR}/README_CN.md" "${ENGINE_DIR}/README_CN.md"
copy_path "${ROOT_DIR}/INSTALL.md" "${ENGINE_DIR}/INSTALL.md"
copy_path "${ROOT_DIR}/INSTALL_CN.md" "${ENGINE_DIR}/INSTALL_CN.md"
copy_path "${ROOT_DIR}/CHANGELOG.md" "${ENGINE_DIR}/CHANGELOG.md"
copy_path "${ROOT_DIR}/LICENSE" "${ENGINE_DIR}/LICENSE"
copy_path "${ROOT_DIR}/bin" "${ENGINE_DIR}/bin"

# Bundle jq so users without it installed can still use quota features.
_jq_src="${JQ_SRC:-$(command -v jq 2>/dev/null || true)}"
if [[ -n "$_jq_src" && -x "$_jq_src" ]]; then
  cp "$_jq_src" "${ENGINE_DIR}/bin/jq"
  chmod +x "${ENGINE_DIR}/bin/jq"
  codesign --force --sign - "${ENGINE_DIR}/bin/jq" 2>/dev/null || true
  echo "Bundled jq from ${_jq_src}"
else
  echo "WARNING: jq not found on build machine; app will require system jq" >&2
fi

copy_path "${ROOT_DIR}/scripts/install-launchd.sh" "${ENGINE_DIR}/scripts/install-launchd.sh"
mkdir -p "${ENGINE_DIR}/logs/raw" "${ENGINE_DIR}/run" "${ENGINE_DIR}/launchd"

cat >"${APP_DIR}/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>StokerMenuBar</string>
  <key>CFBundleIdentifier</key>
  <string>com.stoker.menu-bar</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>Stoker</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.2.0</string>
  <key>CFBundleVersion</key>
  <string>2</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>LSUIElement</key>
  <true/>
</dict>
</plist>
PLIST

echo "Built ${APP_DIR}"
