#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

mkdir -p "$TMP_DIR/logs"

cat >"$TMP_DIR/.env" <<'ENV'
LABEL=com.example.activation-timer.test
SCHEDULE_TIMES="06:15,13:15,21:15"
ACTIVATION_TOOL=codex
ENABLE_STATUS_SNAPSHOTS=0
ENABLE_QUOTA_PREFLIGHT=1
KEEP_AWAKE_MODE=during
KEEP_AWAKE_SECONDS=600
ENV

cat >"$TMP_DIR/logs/status.jsonl" <<'JSONL'
{"timestamp":"2026-05-27 10:00:00 JST","run_id":"r1","tool":"claude","ok":true,"five_hour":{"remaining_percent":72},"weekly":{"remaining_percent":61},"sonnet_weekly":{"remaining_percent":58}}
{"timestamp":"2026-05-27 10:01:00 JST","run_id":"r1","tool":"codex","ok":true,"five_hour":{"remaining_percent":81},"weekly":{"remaining_percent":69}}
JSONL

cat >"$TMP_DIR/logs/usage.jsonl" <<'JSONL'
{"timestamp":"2026-05-27 10:02:00 JST","run_id":"r1","tool":"codex","ok":true,"result":"READY"}
JSONL

json="$(
  ACTIVATION_TIMER_ROOT="$TMP_DIR" \
  ACTIVATION_TIMER_SKIP_LAUNCHCTL=1 \
  "$ROOT_DIR/bin/activation-state.sh" --json
)"

jq -e '
  .installed == false
  and .running == false
  and .label == "com.example.activation-timer.test"
  and .schedule.times == ["06:15", "13:15", "21:15"]
  and .config.activation_tool == "codex"
  and .config.enable_status_snapshots == false
  and .config.enable_quota_preflight == true
  and .keep_awake.mode == "during"
  and .keep_awake.seconds == 600
  and .quota.codex.five_hour.remaining_percent == 81
  and .quota.claude.sonnet_weekly.remaining_percent == 58
  and .last_usage.tool == "codex"
  and .last_usage.result == "READY"
' <<<"$json" >/dev/null

echo "activation-state JSON test passed"
