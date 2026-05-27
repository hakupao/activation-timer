#!/usr/bin/env bash
set -eo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ROOT_DIR}/.env"

if [[ -f "$ENV_FILE" ]]; then
  # Caller's environment takes precedence over .env values.
  _saved_exports="$(export -p)"
  set -a
  # shellcheck source=/dev/null
  source "$ENV_FILE"
  set +a
  eval "$_saved_exports"
  unset _saved_exports
fi

set -u

LABEL="${LABEL:-com.activation-timer.ai-window}"
LEGACY_LABELS="${LEGACY_LABELS:-}"
LAUNCHD_DIR="${ROOT_DIR}/launchd"
LOG_DIR="${ROOT_DIR}/logs"
PLIST_REPO="${LAUNCHD_DIR}/${LABEL}.plist"
PLIST_INSTALLED="${HOME}/Library/LaunchAgents/${LABEL}.plist"
PATH_VALUE="${PATH_VALUE:-${HOME}/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin}"
SCHEDULE_TIMES="${SCHEDULE_TIMES:-07:00,12:00,17:00,22:00}"

usage() {
  cat <<'USAGE'
Usage: install-launchd.sh install|uninstall|status|run-now|print-plist

install     Generate, validate, and load the LaunchAgent.
uninstall   Unload and remove the LaunchAgent.
status      Print launchd status for the agent.
run-now     Trigger the loaded agent immediately.
print-plist Regenerate and print the plist without installing.

Configuration can be set in .env or environment variables:
  LABEL=com.activation-timer.ai-window
  SCHEDULE_TIMES=07:00,12:00,17:00,22:00
  LEGACY_LABELS="old.label.to.remove another.old.label"
USAGE
}

xml_escape() {
  sed \
    -e 's/&/\&amp;/g' \
    -e 's/</\&lt;/g' \
    -e 's/>/\&gt;/g' \
    -e 's/"/\&quot;/g' \
    -e "s/'/\&apos;/g"
}

validate_schedule() {
  local raw_time trimmed time_count=0
  IFS=',' read -r -a times <<<"$SCHEDULE_TIMES"
  for raw_time in "${times[@]}"; do
    trimmed="$(printf '%s' "$raw_time" | tr -d '[:space:]')"
    if ! [[ "$trimmed" =~ ^[0-9]{1,2}:[0-9]{2}$ ]]; then
      echo "SCHEDULE_TIMES entries must be in HH:MM format" >&2
      exit 2
    fi
    local hour="${trimmed%%:*}" minute="${trimmed##*:}"
    if (( 10#$hour < 0 || 10#$hour > 23 )); then
      echo "Hour must be 0-23 in SCHEDULE_TIMES entry: ${trimmed}" >&2
      exit 2
    fi
    if (( 10#$minute < 0 || 10#$minute > 59 )); then
      echo "Minute must be 0-59 in SCHEDULE_TIMES entry: ${trimmed}" >&2
      exit 2
    fi
    time_count=$((time_count + 1))
  done

  if (( time_count == 0 )); then
    echo "SCHEDULE_TIMES must contain at least one time" >&2
    exit 2
  fi
}

render_schedule_intervals() {
  local raw_time trimmed hour minute
  IFS=',' read -r -a times <<<"$SCHEDULE_TIMES"
  for raw_time in "${times[@]}"; do
    trimmed="$(printf '%s' "$raw_time" | tr -d '[:space:]')"
    hour="${trimmed%%:*}"
    minute="${trimmed##*:}"
    cat <<PLIST
    <dict>
      <key>Hour</key>
      <integer>$((10#$hour))</integer>
      <key>Minute</key>
      <integer>$((10#$minute))</integer>
    </dict>
PLIST
  done
}

schedule_description() {
  local raw_time trimmed output="" sep=""
  IFS=',' read -r -a times <<<"$SCHEDULE_TIMES"
  for raw_time in "${times[@]}"; do
    trimmed="$(printf '%s' "$raw_time" | tr -d '[:space:]')"
    local hour="${trimmed%%:*}" minute="${trimmed##*:}"
    output="${output}${sep}$(printf '%02d:%02d' "$((10#$hour))" "$((10#$minute))")"
    sep=", "
  done
  printf '%s' "$output"
}

generate_plist() {
  validate_schedule
  mkdir -p "$LAUNCHD_DIR" "$LOG_DIR" "${HOME}/Library/LaunchAgents"

  local root_xml home_xml path_xml out_xml err_xml
  root_xml="$(printf '%s' "$ROOT_DIR" | xml_escape)"
  home_xml="$(printf '%s' "$HOME" | xml_escape)"
  path_xml="$(printf '%s' "$PATH_VALUE" | xml_escape)"
  out_xml="$(printf '%s' "${LOG_DIR}/launchd.out.log" | xml_escape)"
  err_xml="$(printf '%s' "${LOG_DIR}/launchd.err.log" | xml_escape)"

  cat >"$PLIST_REPO" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>${LABEL}</string>

  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>${root_xml}/bin/activate-ai-window.sh</string>
    <string>--once</string>
  </array>

  <key>WorkingDirectory</key>
  <string>${root_xml}</string>

  <key>EnvironmentVariables</key>
  <dict>
    <key>HOME</key>
    <string>${home_xml}</string>
    <key>PATH</key>
    <string>${path_xml}</string>
  </dict>

  <key>StartCalendarInterval</key>
  <array>
$(render_schedule_intervals)
  </array>

  <key>StandardOutPath</key>
  <string>${out_xml}</string>
  <key>StandardErrorPath</key>
  <string>${err_xml}</string>

  <key>RunAtLoad</key>
  <false/>
</dict>
</plist>
PLIST

  plutil -lint "$PLIST_REPO" >/dev/null
}

bootout_label() {
  local label="$1"
  local plist_path="${HOME}/Library/LaunchAgents/${label}.plist"
  launchctl bootout "gui/${UID}/${label}" >/dev/null 2>&1 || true
  launchctl bootout "gui/${UID}" "$plist_path" >/dev/null 2>&1 || true
}

bootout_if_loaded() {
  bootout_label "$LABEL"
}

remove_legacy_agents() {
  local legacy
  for legacy in $LEGACY_LABELS; do
    [[ "$legacy" == "$LABEL" ]] && continue
    bootout_label "$legacy"
    rm -f "${HOME}/Library/LaunchAgents/${legacy}.plist"
  done
}

install_agent() {
  generate_plist
  remove_legacy_agents
  bootout_if_loaded
  cp "$PLIST_REPO" "$PLIST_INSTALLED"
  launchctl bootstrap "gui/${UID}" "$PLIST_INSTALLED"
  launchctl enable "gui/${UID}/${LABEL}" >/dev/null 2>&1 || true
  echo "Installed ${LABEL}"
  echo "Schedule: $(schedule_description) local time"
  echo "Logs: ${LOG_DIR}/activation.log"
}

uninstall_agent() {
  bootout_if_loaded
  remove_legacy_agents
  rm -f "$PLIST_INSTALLED"
  echo "Uninstalled ${LABEL}"
}

status_agent() {
  launchctl print "gui/${UID}/${LABEL}" || {
    echo "${LABEL} is not currently loaded."
    return 1
  }
}

run_now() {
  launchctl kickstart -k "gui/${UID}/${LABEL}"
  echo "Triggered ${LABEL}. Check ${LOG_DIR}/activation.log"
}

cmd="${1:-}"
case "$cmd" in
  install)
    install_agent
    ;;
  uninstall)
    uninstall_agent
    ;;
  status)
    status_agent
    ;;
  run-now)
    run_now
    ;;
  print-plist)
    generate_plist
    cat "$PLIST_REPO"
    ;;
  -h|--help|help)
    usage
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac
