#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${STOKER_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
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

LABEL="${LABEL:-com.stoker.ai-window}"
SCHEDULE_TIMES="${SCHEDULE_TIMES:-07:00,12:00,17:00,22:00}"
ACTIVATION_TOOL="${ACTIVATION_TOOL:-all}"
CODEX_MODEL="${CODEX_MODEL:-gpt-5.4-mini}"
ENABLE_STATUS_SNAPSHOTS="${ENABLE_STATUS_SNAPSHOTS:-1}"
ENABLE_QUOTA_PREFLIGHT="${ENABLE_QUOTA_PREFLIGHT:-1}"
QUOTA_PREFLIGHT_ON_UNKNOWN="${QUOTA_PREFLIGHT_ON_UNKNOWN:-allow}"
QUOTA_EXHAUSTED_THRESHOLD_PERCENT="${QUOTA_EXHAUSTED_THRESHOLD_PERCENT:-0}"
KEEP_AWAKE_MODE="${KEEP_AWAKE_MODE:-off}"
KEEP_AWAKE_SECONDS="${KEEP_AWAKE_SECONDS:-900}"
JQ_BIN="${JQ_BIN:-$(command -v jq 2>/dev/null || true)}"
if [[ -z "$JQ_BIN" || ! -x "$JQ_BIN" ]]; then
  _bundled_jq="${ROOT_DIR}/bin/jq"
  [[ -x "$_bundled_jq" ]] && JQ_BIN="$_bundled_jq"
  unset _bundled_jq
fi

LOG_DIR="${ROOT_DIR}/logs"
USAGE_LOG="${LOG_DIR}/usage.jsonl"
STATUS_LOG="${LOG_DIR}/status.jsonl"

usage() {
  cat <<'USAGE'
Usage: activation-state.sh --json

Prints a JSON snapshot for the menu bar app and other integrations.
USAGE
}

if [[ "${1:-}" != "--json" ]]; then
  usage >&2
  exit 2
fi

if [[ -z "$JQ_BIN" || ! -x "$JQ_BIN" ]]; then
  echo "jq is required to render activation state JSON" >&2
  exit 1
fi

bool_from_1() {
  if [[ "${1:-}" == "1" ]]; then
    printf 'true'
  else
    printf 'false'
  fi
}

schedule_json() {
  local raw_time trimmed
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
    printf '%02d:%02d\n' "$((10#$hour))" "$((10#$minute))"
  done | "$JQ_BIN" -R -s -c 'split("\n") | map(select(length > 0))'
}

read_latest_by_tool() {
  local file="$1"
  if [[ ! -f "$file" ]]; then
    printf '{}'
    return
  fi

  # shellcheck disable=SC2016 # jq variables are intentionally evaluated by jq.
  "$JQ_BIN" -s -c '
    reduce .[] as $row ({};
      if (($row.tool // null) != null) then
        .[$row.tool] = $row
      else
        .
      end
    )
  ' "$file" 2>/dev/null || printf '{}'
}

read_last_jsonl() {
  local file="$1"
  if [[ ! -f "$file" ]]; then
    printf 'null'
    return
  fi

  "$JQ_BIN" -s -c 'last // null' "$file" 2>/dev/null || printf 'null'
}

installed=false
running=false
launchctl_state="unavailable"
launchctl_error=""

if [[ "${STOKER_SKIP_LAUNCHCTL:-0}" == "1" ]]; then
  launchctl_state="skipped"
else
  launchctl_output="$(launchctl print "gui/${UID}/${LABEL}" 2>&1)" && launchctl_status=0 || launchctl_status=$?
  if [[ "$launchctl_status" == "0" ]]; then
    installed=true
    launchctl_state="$(printf '%s\n' "$launchctl_output" | awk -F'= ' '/state = / {print $2; exit}')"
    [[ -z "$launchctl_state" ]] && launchctl_state="unknown"
    if [[ "$launchctl_state" == "running" ]]; then
      running=true
    fi
  else
    launchctl_state="not_loaded"
    launchctl_error="$(printf '%s' "$launchctl_output" | tr '\n' ' ' | cut -c 1-240)"
  fi
fi

schedule="$(schedule_json)"
quota="$(read_latest_by_tool "$STATUS_LOG")"
last_usage="$(read_last_jsonl "$USAGE_LOG")"
enable_status_snapshots="$(bool_from_1 "$ENABLE_STATUS_SNAPSHOTS")"
enable_quota_preflight="$(bool_from_1 "$ENABLE_QUOTA_PREFLIGHT")"

# shellcheck disable=SC2016 # jq variables are intentionally evaluated by jq.
"$JQ_BIN" -n -c \
  --arg root "$ROOT_DIR" \
  --arg label "$LABEL" \
  --arg activation_tool "$ACTIVATION_TOOL" \
  --arg codex_model "$CODEX_MODEL" \
  --arg quota_preflight_on_unknown "$QUOTA_PREFLIGHT_ON_UNKNOWN" \
  --argjson quota_exhausted_threshold_percent "$QUOTA_EXHAUSTED_THRESHOLD_PERCENT" \
  --arg keep_awake_mode "$KEEP_AWAKE_MODE" \
  --argjson keep_awake_seconds "$KEEP_AWAKE_SECONDS" \
  --arg launchctl_state "$launchctl_state" \
  --arg launchctl_error "$launchctl_error" \
  --argjson installed "$installed" \
  --argjson running "$running" \
  --argjson schedule "$schedule" \
  --argjson quota "$quota" \
  --argjson last_usage "$last_usage" \
  --argjson enable_status_snapshots "$enable_status_snapshots" \
  --argjson enable_quota_preflight "$enable_quota_preflight" '
    {
      root: $root,
      label: $label,
      installed: $installed,
      running: $running,
      launchctl: {
        state: $launchctl_state,
        error: (if $launchctl_error == "" then null else $launchctl_error end)
      },
      schedule: {
        times: $schedule
      },
      config: {
        activation_tool: $activation_tool,
        codex_model: $codex_model,
        enable_status_snapshots: $enable_status_snapshots,
        enable_quota_preflight: $enable_quota_preflight,
        quota_preflight_on_unknown: $quota_preflight_on_unknown,
        quota_exhausted_threshold_percent: $quota_exhausted_threshold_percent
      },
      keep_awake: {
        mode: $keep_awake_mode,
        seconds: $keep_awake_seconds
      },
      quota: $quota,
      last_usage: $last_usage
    }
  '
