#!/usr/bin/env bash
set -o pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ROOT_DIR}/.env"

if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck source=/dev/null
  source "$ENV_FILE"
  set +a
fi

set -u

LOG_DIR="${ROOT_DIR}/logs"
RAW_LOG_DIR="${LOG_DIR}/raw"
USAGE_LOG="${LOG_DIR}/usage.jsonl"
STATUS_LOG="${LOG_DIR}/status.jsonl"
RUN_DIR="${ROOT_DIR}/run"
LOCK_DIR="${RUN_DIR}/activation.lock"

PATH_VALUE="${PATH_VALUE:-${HOME}/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin}"
export PATH="${PATH_VALUE}:${PATH:-}"
export HOME="${HOME}"

CLAUDE_BIN="${CLAUDE_BIN:-$(command -v claude 2>/dev/null || true)}"
CODEX_BIN="${CODEX_BIN:-$(command -v codex 2>/dev/null || true)}"
JQ_BIN="${JQ_BIN:-$(command -v jq 2>/dev/null || true)}"
NODE_BIN="${NODE_BIN:-$(command -v node 2>/dev/null || true)}"
OMC_BIN="${OMC_BIN:-$(command -v omc 2>/dev/null || true)}"
ACTIVATION_PROMPT="${ACTIVATION_PROMPT:-Reply exactly READY. Do not inspect files, run tools, or modify anything.}"
TIMEOUT_SECONDS="${TIMEOUT_SECONDS:-120}"
ACTIVATION_TOOL="${ACTIVATION_TOOL:-all}"
ENABLE_STATUS_SNAPSHOTS="${ENABLE_STATUS_SNAPSHOTS:-1}"

MODE="once"
TOOL="$ACTIVATION_TOOL"

usage() {
  cat <<'USAGE'
Usage: activate-ai-window.sh [--once] [--dry-run] [--check] [--status] [--tool all|claude|codex]

Runs a tiny scheduled check-in against Claude Code and Codex to start usage
windows at predictable times. The default mode is --once.

Environment overrides:
  CLAUDE_BIN=/path/to/claude
  CODEX_BIN=/path/to/codex
  ACTIVATION_PROMPT='Reply exactly READY...'
  TIMEOUT_SECONDS=120
  ACTIVATION_TOOL=all
  ENABLE_STATUS_SNAPSHOTS=1
  JQ_BIN=/path/to/jq
  NODE_BIN=/path/to/node
  OMC_BIN=/path/to/omc
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --once)
      MODE="once"
      shift
      ;;
    --dry-run)
      MODE="dry-run"
      shift
      ;;
    --check)
      MODE="check"
      shift
      ;;
    --status)
      MODE="status"
      shift
      ;;
    --tool)
      if [[ $# -lt 2 ]]; then
        echo "--tool requires all, claude, or codex" >&2
        exit 2
      fi
      TOOL="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

case "$TOOL" in
  all|claude|codex) ;;
  *)
    echo "--tool must be all, claude, or codex" >&2
    exit 2
    ;;
esac

mkdir -p "$LOG_DIR" "$RAW_LOG_DIR" "$RUN_DIR"

timestamp() {
  date '+%Y-%m-%d %H:%M:%S %Z'
}

stamp_for_file() {
  date '+%Y%m%d-%H%M%S'
}

log() {
  printf '[%s] %s\n' "$(timestamp)" "$*" | tee -a "${LOG_DIR}/activation.log"
}

require_bin() {
  local name="$1"
  local path="$2"
  if [[ -z "$path" || ! -x "$path" ]]; then
    log "ERROR: ${name} binary not found or not executable: ${path:-<empty>}"
    return 1
  fi
}

run_with_timeout() {
  local output_file="$1"
  shift

  "$@" >"$output_file" 2>&1 &
  local pid=$!
  local elapsed=0

  while kill -0 "$pid" 2>/dev/null; do
    if (( elapsed >= TIMEOUT_SECONDS )); then
      kill "$pid" 2>/dev/null || true
      sleep 2
      kill -9 "$pid" 2>/dev/null || true
      wait "$pid" 2>/dev/null || true
      return 124
    fi
    sleep 1
    elapsed=$((elapsed + 1))
  done

  wait "$pid"
}

summarize_output() {
  local output_file="$1"
  if grep -q 'READY' "$output_file" 2>/dev/null; then
    printf 'result=READY'
    return
  fi

  local first_line
  first_line="$(sed -n '1p' "$output_file" | tr '\n' ' ' | cut -c 1-180)"
  if [[ -n "$first_line" ]]; then
    printf 'result=%s' "$first_line"
  else
    printf 'result=<empty>'
  fi
}

record_claude_usage() {
  local exit_code="$1"
  local output_file="$2"

  if [[ -z "$JQ_BIN" || ! -x "$JQ_BIN" ]]; then
    log "WARNING: jq not found; Claude usage snapshot was not recorded"
    return 0
  fi

  if "$JQ_BIN" -c -Rcs \
    --arg timestamp "$(timestamp)" \
    --arg tool "claude" \
    --argjson exit_code "$exit_code" \
    --arg raw_log "$output_file" '
      (split("\n") | map(select(length > 0) | try fromjson catch empty) | first // {}) as $o
      | {
          timestamp: $timestamp,
          tool: $tool,
          exit_code: $exit_code,
          ok: ($exit_code == 0),
          result: ($o.result // null),
          session_id: ($o.session_id // null),
          model: ($o.model // $o.model_name // null),
          duration_ms: ($o.duration_ms // null),
          total_cost_usd: ($o.total_cost_usd // null),
          usage: ($o.usage // $o.token_usage // null),
          raw_log: $raw_log
        }
    ' "$output_file" >>"$USAGE_LOG" 2>/dev/null; then
    log "Claude usage snapshot recorded usage_log=${USAGE_LOG}"
  else
    log "WARNING: failed to parse Claude usage snapshot from ${output_file}"
  fi
}

record_codex_usage() {
  local exit_code="$1"
  local output_file="$2"

  if [[ -z "$JQ_BIN" || ! -x "$JQ_BIN" ]]; then
    log "WARNING: jq not found; Codex usage snapshot was not recorded"
    return 0
  fi

  if "$JQ_BIN" -c -Rcs \
    --arg timestamp "$(timestamp)" \
    --arg tool "codex" \
    --argjson exit_code "$exit_code" \
    --arg raw_log "$output_file" '
      (split("\n") | map(select(length > 0) | try fromjson catch empty)) as $events
      | ($events | map(select(.type == "thread.started")) | first // {}) as $thread
      | ($events | map(select(.type == "turn.completed")) | last // {}) as $completed
      | ($events | map(select(.type == "turn.failed")) | last // null) as $failed
      | ($events | map(select(.type == "item.completed" and .item.type == "agent_message")) | last // {}) as $message
      | {
          timestamp: $timestamp,
          tool: $tool,
          exit_code: $exit_code,
          ok: ($exit_code == 0 and ($completed.type == "turn.completed")),
          thread_id: ($thread.thread_id // null),
          result: ($message.item.text // null),
          usage: ($completed.usage // null),
          failure: ($failed // null),
          event_count: ($events | length),
          raw_log: $raw_log
        }
    ' "$output_file" >>"$USAGE_LOG" 2>/dev/null; then
    log "Codex usage snapshot recorded usage_log=${USAGE_LOG}"
  else
    log "WARNING: failed to parse Codex usage snapshot from ${output_file}"
  fi
}

record_claude_status() {
  local output_file="${RAW_LOG_DIR}/$(stamp_for_file)-claude-status.log"
  local status_exit=0
  local auth_status="{}"
  local cache_file="${HOME}/.claude/plugins/oh-my-claudecode/.usage-cache-anthropic.json"

  if [[ -z "$JQ_BIN" || ! -x "$JQ_BIN" ]]; then
    log "WARNING: jq not found; Claude status snapshot was not recorded"
    return 0
  fi

  if [[ -z "$OMC_BIN" || ! -x "$OMC_BIN" ]]; then
    log "WARNING: omc not found; Claude quota status snapshot was not recorded"
    return 1
  fi

  "$OMC_BIN" wait status >"$output_file" 2>&1 || status_exit=$?

  if [[ -n "$CLAUDE_BIN" && -x "$CLAUDE_BIN" ]]; then
    auth_status="$("$CLAUDE_BIN" auth status 2>/dev/null || printf '{}')"
  fi

  if [[ ! -f "$cache_file" ]]; then
    log "WARNING: Claude usage cache not found after status query"
    return 1
  fi

  "$JQ_BIN" -c \
    --arg timestamp "$(timestamp)" \
    --arg tool "claude" \
    --argjson query_exit_code "$status_exit" \
    --arg raw_log "$output_file" \
    --argjson auth "$auth_status" '
      . as $cache
      | ($cache.data // {}) as $d
      | {
          timestamp: $timestamp,
          tool: $tool,
          ok: ($query_exit_code == 0 and ($cache.error // false | not)),
          query_exit_code: $query_exit_code,
          source: ($cache.source // null),
          subscription_type: ($auth.subscriptionType // null),
          cache_timestamp_ms: ($cache.timestamp // null),
          last_success_at_ms: ($cache.lastSuccessAt // null),
          five_hour: {
            used_percent: ($d.fiveHourPercent // null),
            remaining_percent: (if $d.fiveHourPercent == null then null else (100 - $d.fiveHourPercent) end),
            resets_at: ($d.fiveHourResetsAt // null)
          },
          weekly: {
            used_percent: ($d.weeklyPercent // null),
            remaining_percent: (if $d.weeklyPercent == null then null else (100 - $d.weeklyPercent) end),
            resets_at: ($d.weeklyResetsAt // null)
          },
          sonnet_weekly: {
            used_percent: ($d.sonnetWeeklyPercent // null),
            remaining_percent: (if $d.sonnetWeeklyPercent == null then null else (100 - $d.sonnetWeeklyPercent) end),
            resets_at: ($d.sonnetWeeklyResetsAt // null)
          },
          raw_log: $raw_log
        }
    ' "$cache_file" >>"$STATUS_LOG" 2>/dev/null || {
      log "WARNING: failed to parse Claude status snapshot"
      return 1
    }

  log "Claude status snapshot recorded status_log=${STATUS_LOG}"
}

record_codex_status() {
  local output_file="${RAW_LOG_DIR}/$(stamp_for_file)-codex-status.log"

  if [[ -z "$JQ_BIN" || ! -x "$JQ_BIN" ]]; then
    log "WARNING: jq not found; Codex status snapshot was not recorded"
    return 0
  fi

  if [[ -z "$NODE_BIN" || ! -x "$NODE_BIN" ]]; then
    log "WARNING: node not found; Codex status snapshot was not recorded"
    return 1
  fi

  if [[ -z "$CODEX_BIN" || ! -x "$CODEX_BIN" ]]; then
    log "WARNING: Codex binary not found; Codex status snapshot was not recorded"
    return 1
  fi

  CODEX_BIN="$CODEX_BIN" "$NODE_BIN" >"$output_file" 2>&1 <<'NODE' || true
const { spawn } = require("child_process");

const codexBin = process.env.CODEX_BIN || "codex";
const child = spawn(codexBin, ["app-server", "--listen", "stdio://"], {
  cwd: process.cwd(),
  stdio: ["pipe", "pipe", "pipe"],
});

let stdoutBuffer = "";
let settled = false;

function finish(code) {
  if (settled) return;
  settled = true;
  try { child.stdin.end(); } catch {}
  try { child.kill("SIGTERM"); } catch {}
  process.exit(code);
}

function send(obj) {
  child.stdin.write(JSON.stringify(obj) + "\n");
}

const timer = setTimeout(() => {
  console.log(JSON.stringify({ kind: "codex_rate_limits_error", error: "timeout" }));
  finish(124);
}, 15000);

child.stdout.on("data", (buf) => {
  stdoutBuffer += buf.toString();
  let idx;
  while ((idx = stdoutBuffer.indexOf("\n")) >= 0) {
    const line = stdoutBuffer.slice(0, idx).trim();
    stdoutBuffer = stdoutBuffer.slice(idx + 1);
    if (!line) continue;

    let msg;
    try {
      msg = JSON.parse(line);
    } catch {
      continue;
    }

    if (msg.id === 1) {
      send({ id: 2, method: "account/rateLimits/read" });
      continue;
    }

    if (msg.id === 2) {
      clearTimeout(timer);
      if (msg.error) {
        console.log(JSON.stringify({ kind: "codex_rate_limits_error", error: msg.error }));
        finish(1);
      } else {
        console.log(JSON.stringify({ kind: "codex_rate_limits", result: msg.result }));
        finish(0);
      }
    }
  }
});

child.stderr.on("data", (buf) => {
  process.stderr.write(buf);
});

child.on("error", (err) => {
  console.log(JSON.stringify({ kind: "codex_rate_limits_error", error: err.message }));
  clearTimeout(timer);
  finish(1);
});

child.on("exit", (code, signal) => {
  if (!settled) {
    console.log(JSON.stringify({ kind: "codex_rate_limits_error", error: `app-server exited code=${code} signal=${signal}` }));
    clearTimeout(timer);
    finish(code || 1);
  }
});

send({
  id: 1,
  method: "initialize",
  params: {
    clientInfo: { name: "activation-timer", version: "0.1.0" },
    capabilities: null,
  },
});
NODE

  "$JQ_BIN" -c -Rcs \
    --arg timestamp "$(timestamp)" \
    --arg tool "codex" \
    --arg raw_log "$output_file" '
      (split("\n") | map(select(length > 0) | try fromjson catch empty)) as $events
      | ($events | map(select(.kind == "codex_rate_limits")) | last) as $record
      | ($events | map(select(.kind == "codex_rate_limits_error")) | last // null) as $error
      | ($record.result.rateLimitsByLimitId.codex // $record.result.rateLimits // {}) as $snapshot
      | ($snapshot.primary // {}) as $primary
      | ($snapshot.secondary // {}) as $secondary
      | {
          timestamp: $timestamp,
          tool: $tool,
          ok: ($record != null),
          plan_type: ($snapshot.planType // null),
          limit_id: ($snapshot.limitId // null),
          limit_name: ($snapshot.limitName // null),
          rate_limit_reached_type: ($snapshot.rateLimitReachedType // null),
          credits: ($snapshot.credits // null),
          five_hour: {
            used_percent: ($primary.usedPercent // null),
            remaining_percent: (if $primary.usedPercent == null then null else (100 - $primary.usedPercent) end),
            window_minutes: ($primary.windowDurationMins // null),
            resets_at_epoch: ($primary.resetsAt // null),
            resets_at: (if $primary.resetsAt == null then null else ($primary.resetsAt | todateiso8601) end)
          },
          weekly: {
            used_percent: ($secondary.usedPercent // null),
            remaining_percent: (if $secondary.usedPercent == null then null else (100 - $secondary.usedPercent) end),
            window_minutes: ($secondary.windowDurationMins // null),
            resets_at_epoch: ($secondary.resetsAt // null),
            resets_at: (if $secondary.resetsAt == null then null else ($secondary.resetsAt | todateiso8601) end)
          },
          error: $error,
          raw_log: $raw_log
        }
    ' "$output_file" >>"$STATUS_LOG" 2>/dev/null || {
      log "WARNING: failed to parse Codex status snapshot"
      return 1
    }

  log "Codex status snapshot recorded status_log=${STATUS_LOG}"
}

record_status_snapshots() {
  local status=0

  if [[ "$TOOL" == "all" || "$TOOL" == "claude" ]]; then
    record_claude_status || status=1
  fi

  if [[ "$TOOL" == "all" || "$TOOL" == "codex" ]]; then
    record_codex_status || status=1
  fi

  return "$status"
}

run_claude() {
  local output_file="${RAW_LOG_DIR}/$(stamp_for_file)-claude.log"
  local cmd=(
    "$CLAUDE_BIN"
    -p "$ACTIVATION_PROMPT"
    --output-format json
    --no-session-persistence
    --disable-slash-commands
    --tools ""
  )

  if [[ "$MODE" == "dry-run" ]]; then
    log "DRY-RUN Claude: ${cmd[*]}"
    return 0
  fi

  require_bin "Claude" "$CLAUDE_BIN" || return 1
  log "Claude job started"
  run_with_timeout "$output_file" "${cmd[@]}"
  local exit_code=$?
  record_claude_usage "$exit_code" "$output_file"
  log "Claude job completed exit=${exit_code} $(summarize_output "$output_file") raw=${output_file}"
  return "$exit_code"
}

run_codex() {
  local output_file="${RAW_LOG_DIR}/$(stamp_for_file)-codex.log"
  local cmd=(
    "$CODEX_BIN"
    exec
    --cd "$ROOT_DIR"
    --ephemeral
    --skip-git-repo-check
    --sandbox read-only
    --json
    "$ACTIVATION_PROMPT"
  )

  if [[ "$MODE" == "dry-run" ]]; then
    log "DRY-RUN Codex: ${cmd[*]}"
    return 0
  fi

  require_bin "Codex" "$CODEX_BIN" || return 1
  log "Codex job started"
  run_with_timeout "$output_file" "${cmd[@]}"
  local exit_code=$?
  record_codex_usage "$exit_code" "$output_file"
  log "Codex job completed exit=${exit_code} $(summarize_output "$output_file") raw=${output_file}"
  return "$exit_code"
}

run_check() {
  local status=0
  if [[ "$TOOL" == "all" || "$TOOL" == "claude" ]]; then
    if require_bin "Claude" "$CLAUDE_BIN"; then
      log "Claude binary: $CLAUDE_BIN ($("$CLAUDE_BIN" --version 2>&1 | tr '\n' ' '))"
    else
      status=1
    fi
  fi
  if [[ "$TOOL" == "all" || "$TOOL" == "codex" ]]; then
    if require_bin "Codex" "$CODEX_BIN"; then
      log "Codex binary: $CODEX_BIN ($("$CODEX_BIN" --version 2>&1 | tr '\n' ' '))"
    else
      status=1
    fi
  fi
  if [[ -n "$JQ_BIN" && -x "$JQ_BIN" ]]; then
    log "jq binary: $JQ_BIN ($("$JQ_BIN" --version 2>&1 | tr '\n' ' '))"
  else
    log "WARNING: jq not found; usage.jsonl parsing will be disabled"
  fi
  if [[ -n "$NODE_BIN" && -x "$NODE_BIN" ]]; then
    log "node binary: $NODE_BIN ($("$NODE_BIN" --version 2>&1 | tr '\n' ' '))"
  else
    log "WARNING: node not found; Codex status snapshots will be disabled"
  fi
  if [[ -n "$OMC_BIN" && -x "$OMC_BIN" ]]; then
    log "omc binary: $OMC_BIN ($("$OMC_BIN" --version 2>&1 | tr '\n' ' '))"
  else
    log "WARNING: omc not found; Claude quota status snapshots will be disabled"
  fi
  return "$status"
}

main() {
  cd "$ROOT_DIR"

  if [[ "$MODE" == "check" ]]; then
    run_check
    return $?
  fi

  if [[ "$MODE" == "status" ]]; then
    record_status_snapshots
    return $?
  fi

  if ! mkdir "$LOCK_DIR" 2>/dev/null; then
    log "Another activation run is already active; skipping."
    return 0
  fi
  trap 'rmdir "$LOCK_DIR" 2>/dev/null || true' EXIT

  local status=0
  log "Activation run started mode=${MODE} tool=${TOOL} root=${ROOT_DIR}"

  if [[ "$TOOL" == "all" || "$TOOL" == "claude" ]]; then
    run_claude || status=$?
  fi

  if [[ "$TOOL" == "all" || "$TOOL" == "codex" ]]; then
    run_codex || status=$?
  fi

  if [[ "$MODE" == "dry-run" ]]; then
    log "Status snapshots skipped in dry-run mode"
  elif [[ "$ENABLE_STATUS_SNAPSHOTS" == "1" ]]; then
    record_status_snapshots || log "WARNING: one or more status snapshots failed"
  else
    log "Status snapshots disabled by ENABLE_STATUS_SNAPSHOTS=${ENABLE_STATUS_SNAPSHOTS}"
  fi

  log "Activation run finished exit=${status}"
  return "$status"
}

main "$@"
