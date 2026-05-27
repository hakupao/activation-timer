[English](README.md) | [中文](README_CN.md)

# Activation Timer

> A tiny macOS scheduler that sends low-cost Claude Code and Codex check-ins at fixed times, then records activation logs, per-run token usage, and quota status snapshots.

[![CI](https://github.com/hakupao/activation-timer/actions/workflows/ci.yml/badge.svg)](https://github.com/hakupao/activation-timer/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

## About

Activation Timer is a small Bash-based utility for people who want predictable Claude Code and Codex usage-window start times. It installs a macOS `launchd` agent that runs in a dedicated lightweight folder, asks each CLI to reply `READY`, and keeps the prompt intentionally small so it does not scan real projects or modify files.

The default schedule is `07:00`, `12:00`, `17:00`, and `22:00` local macOS time.

## Features

- Scheduled Claude Code and Codex activation through macOS `launchd`.
- A minimal prompt that tells both CLIs not to inspect files, run tools, or modify anything.
- Human-readable run history in `logs/activation.log`.
- Structured per-run usage records in `logs/usage.jsonl`.
- Structured five-hour and weekly quota snapshots in `logs/status.jsonl`.
- Quota preflight that skips activation gracefully when a known quota is exhausted.
- Clone-friendly configuration through `.env`.
- Safe manual commands for dry runs, dependency checks, quota checks, and uninstall.

## Requirements

- macOS with `launchctl`.
- Bash.
- Claude Code CLI, authenticated with your Claude plan.
- Codex CLI, authenticated with ChatGPT.
- `jq` for structured JSONL parsing.
- Node.js for Codex quota status queries.
- `omc` / oh-my-claudecode for Claude quota status snapshots.

The activation itself only requires the Claude and Codex CLIs. Quota snapshots gracefully warn and skip if optional helpers such as `omc`, `node`, or `jq` are missing.

## Quick Start

```sh
git clone https://github.com/hakupao/activation-timer.git
cd activation-timer
cp .env.example .env
./install.sh check
./install.sh dry-run
./install.sh
```

`./install.sh` defaults to `install`, which generates a user LaunchAgent and loads it into the current macOS GUI session.

## Commands

```sh
./install.sh check        # verify local dependencies
./install.sh dry-run      # show commands without sending model prompts
./install.sh quota        # query quota status without sending model prompts
./install.sh status       # show launchd status
./install.sh run-now      # trigger once; this sends model prompts
./install.sh uninstall    # unload and remove the LaunchAgent
./install.sh print-plist  # print the generated launchd plist
```

You can also call the runner directly:

```sh
./bin/activate-ai-window.sh --once
./bin/activate-ai-window.sh --status
./bin/activate-ai-window.sh --once --tool claude
./bin/activate-ai-window.sh --once --tool codex
```

## Daily Operation

Use these checks to confirm the timer is installed, waiting, and recording results:

```sh
./install.sh status
tail -f logs/activation.log
tail -n 20 logs/usage.jsonl | jq
tail -n 20 logs/status.jsonl | jq
```

`./install.sh status` should show a loaded LaunchAgent with calendar triggers for your configured hours. `state = not running` is normal between scheduled runs; it means the job is loaded and waiting for the next trigger. During a trigger it may briefly show `running`.

`logs/activation.log` is the quickest human-readable view. A normal run looks like this:

```text
Activation run started ...
Quota preflight started
Claude job started
Codex job started
Activation run finished exit=0
```

If quota preflight decides not to send a prompt, the run stays clean and records a skip:

```text
claude job skipped by quota preflight reason=quota_exhausted
codex job skipped by quota preflight reason=quota_exhausted
```

`logs/usage.jsonl` is the structured success/skip record. Successful activations usually include `ok: true`, `result: READY`, and `exit_code: 0`. Skipped activations include `skipped: true` and a `skip_reason`.

Manual command guide:

- `./install.sh status`: checks whether local `launchd` has the timer loaded.
- `./install.sh quota`: checks quota status without sending prompts.
- `./install.sh dry-run`: prints the planned commands without sending prompts.
- `./install.sh run-now`: triggers the installed LaunchAgent once and may consume usage if quota is available.

## Configuration

Copy `.env.example` to `.env` and adjust values:

| Variable | Description | Default |
| --- | --- | --- |
| `LABEL` | macOS LaunchAgent label | `com.activation-timer.ai-window` |
| `SCHEDULE_HOURS` | Comma-separated local hours | `7,12,17,22` |
| `SCHEDULE_MINUTE` | Shared minute for all schedule entries | `0` |
| `ACTIVATION_TOOL` | `all`, `claude`, or `codex` | `all` |
| `ACTIVATION_PROMPT` | Low-cost prompt sent to the CLIs | `Reply exactly READY...` |
| `TIMEOUT_SECONDS` | Per-tool timeout | `120` |
| `ENABLE_STATUS_SNAPSHOTS` | Record quota snapshots after real activation | `1` |
| `ENABLE_QUOTA_PREFLIGHT` | Check quota before sending prompts | `1` |
| `QUOTA_PREFLIGHT_ON_UNKNOWN` | `allow` or `skip` when quota cannot be checked | `allow` |
| `QUOTA_EXHAUSTED_THRESHOLD_PERCENT` | Skip when remaining quota is at or below this percent | `0` |
| `CLAUDE_BIN` | Optional Claude binary override | auto-discovered |
| `CODEX_BIN` | Optional Codex binary override | auto-discovered |
| `JQ_BIN` | Optional `jq` binary override | auto-discovered |
| `NODE_BIN` | Optional Node.js binary override | auto-discovered |
| `OMC_BIN` | Optional `omc` binary override | auto-discovered |
| `PATH_VALUE` | PATH used by launchd and the runner | Homebrew/local/system defaults |

After changing schedule or label values, reinstall the LaunchAgent:

```sh
./install.sh install
```

## Logs

```sh
tail -f logs/activation.log
tail -20 logs/usage.jsonl | jq
tail -20 logs/status.jsonl | jq
```

Log files:

- `logs/activation.log`: human-readable run history.
- `logs/usage.jsonl`: one structured usage snapshot per tool per real run.
- `logs/status.jsonl`: five-hour and weekly quota snapshots per tool.
- `logs/raw/`: raw Claude/Codex/status outputs for debugging and future parsing.
- `logs/launchd.out.log` and `logs/launchd.err.log`: launchd stdout/stderr.

## How It Works

```text
activation-timer/
├── bin/
│   └── activate-ai-window.sh
├── scripts/
│   └── install-launchd.sh
├── launchd/
│   └── generated plist files
├── logs/
│   └── generated run logs
├── .env.example
├── CHANGELOG.md
├── CONTRIBUTING.md
├── install.sh
├── LICENSE
├── README.md
└── README_CN.md
```

The installer computes the project root at runtime, writes an absolute-path plist for macOS `launchd`, and installs it under `~/Library/LaunchAgents/`. The runner also computes its project root at runtime, so the project can be cloned to a different directory without editing scripts.

GitHub Actions only validates the repository scripts on push and pull requests. Scheduled activation always runs locally on the Mac where `./install.sh install` was executed.

## Safety Notes

- `dry-run` does not send model prompts.
- `quota` only queries account/rate-limit status paths and local caches; it does not send a model prompt.
- `run-now` and scheduled activation first run quota preflight, then send one small prompt per enabled tool only when quota appears available.
- If quota is known to be exhausted, the tool is skipped and recorded in `logs/usage.jsonl` with `skipped: true`.
- The default Claude invocation disables slash commands, disables session persistence, and uses no tools.
- The default Codex invocation uses `--ephemeral`, `--skip-git-repo-check`, and `--sandbox read-only`.
- The generated plist is intentionally ignored by git because it contains machine-specific absolute paths.

## Uninstall

```sh
./install.sh uninstall
```

If you are migrating from an older local label, set `LEGACY_LABELS="old.label"` when installing so the old LaunchAgent is removed and does not double-trigger.

## Contributing

Run local validation before sending changes:

```sh
./scripts/validate.sh
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for development notes.

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for release history.

## License

Distributed under the MIT License. See [LICENSE](LICENSE) for more information.
