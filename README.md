[English](README.md) | [中文](README_CN.md)

# Activation Timer

> A tiny macOS scheduler that sends low-cost Claude Code and Codex check-ins at fixed times, then records activation logs, per-run token usage, and quota status snapshots.

[![CI](https://github.com/hakupao/activation-timer/actions/workflows/ci.yml/badge.svg)](https://github.com/hakupao/activation-timer/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

## About

Activation Timer is a small Bash-based utility for people who want predictable Claude Code and Codex usage-window start times. It installs a macOS `launchd` agent that runs in a dedicated lightweight folder, asks each CLI to reply `READY`, and keeps the prompt intentionally small so it does not scan real projects or modify files.

The default schedule is `07:00`, `12:00`, `17:00`, and `22:00` local macOS time.

<p align="center">
  <img src="docs/images/activity-en.png" width="460" alt="Activation Timer — Activity dashboard" />
</p>

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

Choose one distribution:

- **CLI/launchd package**: for advanced users who want the lightest possible
  install and direct shell control.
- **Menu bar app package**: for beginners who want a GUI monitor and settings
  panel while keeping the same local scheduler underneath.

### CLI / launchd

```sh
git clone https://github.com/hakupao/activation-timer.git
cd activation-timer
cp .env.example .env
./install.sh check
./install.sh dry-run
./install.sh
```

`./install.sh` defaults to `install`, which generates a user LaunchAgent and loads it into the current macOS GUI session.

### Menu bar app

Download the GUI DMG, drag `Activation Timer.app` to `Applications`, open it,
then use the status-bar menu to install/reload the schedule, refresh quota, run
once, pause the schedule, and edit settings. The app bundles the same CLI engine
and installs its working copy under
`~/Library/Application Support/Activation Timer/activation-timer`.

See [INSTALL.md](INSTALL.md) for complete beginner and advanced installation
steps.

## Commands

```sh
./install.sh check        # verify local dependencies
./install.sh dry-run      # show commands without sending model prompts
./install.sh quota        # query quota status without sending model prompts
./install.sh app-status   # print JSON status for the menu bar app
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
| `SCHEDULE_TIMES` | Comma-separated `HH:MM` schedule entries; each time point is independent | `"07:00,12:00,17:00,22:00"` |
| `ACTIVATION_TOOL` | `all`, `claude`, or `codex` | `all` |
| `ACTIVATION_PROMPT` | Low-cost prompt sent to the CLIs | `Reply exactly READY...` |
| `TIMEOUT_SECONDS` | Per-tool timeout | `120` |
| `ENABLE_STATUS_SNAPSHOTS` | Record quota snapshots after real activation | `1` |
| `ENABLE_QUOTA_PREFLIGHT` | Check quota before sending prompts | `1` |
| `QUOTA_PREFLIGHT_ON_UNKNOWN` | `allow` or `skip` when quota cannot be checked | `allow` |
| `QUOTA_EXHAUSTED_THRESHOLD_PERCENT` | Skip when remaining quota is at or below this percent | `0` |
| `KEEP_AWAKE_MODE` | `off`, `during`, or `always`; scheduled CLI runs use `caffeinate` when not `off` | `off` |
| `KEEP_AWAKE_SECONDS` | Bounded keep-awake duration for each real activation run | `900` |
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

## Menu Bar App

The CLI/launchd workflow remains the primary engine. The optional menu bar app
is a separate beginner-friendly distribution that adds a macOS status-bar
control surface for the same configuration, schedule, quota snapshots, and logs.

Highlights:

- **Activity dashboard** — per-tool quota-trend chart (5-hour / weekly), a run-history timeline with expandable per-run details (tokens, cost, duration, session), and summary stats with date-range / status / tool filters.
- **Settings** — edit independent schedule times, toggle Claude/Codex, and configure advanced options (quota preflight, post-run snapshots, keep-awake, launch at login).
- **Bilingual UI** with an EN / 中 switch; the appearance follows the system Light/Dark setting.
- **Environment Check** that detects required and optional CLI tools.
- **Export run history to CSV.**

<p align="center">
  <img src="docs/images/settings-en.png" width="460" alt="Activation Timer — Settings tab" />
</p>

Build the app bundle locally:

```sh
./app/ActivationTimerMenuBar/build-app.sh
open "dist/Activation Timer.app"
```

The app calls the existing scripts instead of replacing them:

- `./install.sh app-status` for a JSON state snapshot.
- `./install.sh install` to save/reload the LaunchAgent after settings changes.
- `./install.sh run-now`, `quota`, `dry-run`, and `uninstall` for menu actions.

Set `KEEP_AWAKE_MODE=always` in the app if you want it to keep macOS awake while
the menu bar app is open. Scheduled activation still works without the app
running, and `KEEP_AWAKE_MODE=during` protects only real activation runs.

## Release Packaging

Maintainers can build both publishable artifacts with one command:

```sh
./scripts/package-release.sh
```

The output under `dist/` is split by audience:

- `activation-timer-cli-<version>.tar.gz`: lightweight CLI/launchd package.
- `activation-timer-gui-<version>.dmg`: GUI app package for beginner users.
- `activation-timer-gui-<version>.zip`: fallback GUI app archive.

## How It Works

### Architecture Overview

The project has two entry points — CLI and menu bar app — that share the same shell engine:

```text
┌──────────────────────────────────────────────────────────┐
│                     Entry Points                         │
│                                                          │
│   ┌─────────────┐              ┌──────────────────────┐  │
│   │   launchd    │              │  Menu Bar App        │  │
│   │  (scheduled) │              │  (SwiftUI GUI)       │  │
│   └──────┬──────┘              └──────────┬───────────┘  │
│          │                                │              │
│          │ triggers at                    │ calls via    │
│          │ HH:MM                          │ Process()    │
│          ▼                                ▼              │
│   ┌─────────────────────────────────────────────────┐    │
│   │          Shared Shell Scripts                    │    │
│   │                                                 │    │
│   │  bin/activate-ai-window.sh  (activation runner) │    │
│   │  bin/activation-state.sh    (JSON state query)  │    │
│   │  scripts/install-launchd.sh (launchd manager)   │    │
│   └────────────────────┬────────────────────────────┘    │
│                        │                                 │
│               sends minimal prompt                       │
│                        │                                 │
│              ┌─────────┴─────────┐                       │
│              ▼                   ▼                        │
│        ┌───────────┐      ┌───────────┐                  │
│        │Claude Code│      │  Codex    │                  │
│        │   CLI     │      │   CLI     │                  │
│        └───────────┘      └───────────┘                  │
└──────────────────────────────────────────────────────────┘
```

### CLI Runtime Flow

When launchd triggers at a scheduled time (or you run `./install.sh run-now`), the activation script executes this sequence:

1. **Load config** — reads `.env` for schedule, tool selection, quota settings, and binary paths.
2. **Acquire lock** — creates `run/activation.lock` to prevent concurrent runs; a second trigger during an active run is skipped gracefully.
3. **Quota preflight** (optional) — queries Claude and Codex quota status *before* sending any prompt. If a tool's quota is exhausted, that tool is skipped and the skip is recorded in `logs/usage.jsonl`.
4. **Send prompt** — calls each enabled CLI with a minimal prompt (`Reply exactly READY`). Claude runs in ultra-lightweight mode (see [Cost Optimization](#cost-optimization)). Codex runs with `--ephemeral`, `--skip-git-repo-check`, `--sandbox read-only`, and stripped-down config (see below).
5. **Record usage** — parses each CLI's JSON output with `jq` and appends a structured record to `logs/usage.jsonl` (token counts, cost, session ID, model, duration, etc.).
6. **Post-run snapshots** (optional) — takes another quota snapshot after activation and appends it to `logs/status.jsonl`.
7. **Release lock** — removes the lock directory so the next scheduled run can proceed.

Timeout protection: each CLI call is wrapped in a background process with a configurable timeout (default 120 s). If a CLI hangs, it receives SIGTERM, then SIGKILL after 2 s.

### Menu Bar App

The SwiftUI app is a thin GUI shell — it does not contain its own scheduler or activation logic. Every operation delegates to the same shell scripts:

| App action | Shell call |
| --- | --- |
| Read status | `bin/activation-state.sh --json` |
| Toggle schedule | `install.sh install` or `install.sh uninstall` |
| Save settings | Write `.env`, then `install.sh install` |
| Run once | `install.sh run-now` |

The app calls scripts through `Process()` (Foundation), reads stdout, and decodes the JSON into Swift model types.

### Where Does Activation Run?

Both CLIs are invoked inside the **activation-timer project directory itself** — never inside your real projects. This is a lightweight folder that contains only scripts and logs, so there is nothing for the CLIs to scan or modify.

| Installation method | Working directory | Who creates it |
| --- | --- | --- |
| CLI (`git clone`) | The cloned repo, e.g. `~/activation-timer` | You, when you clone |
| Menu bar app (dev build) | Same cloned repo | Same |
| Menu bar app (.app / DMG) | `~/Library/Application Support/Activation Timer/activation-timer/` | App creates it automatically on first launch by copying scripts from the app bundle |

How the directory is resolved:

- **Shell scripts**: `ROOT_DIR` is computed at runtime by walking up from the script's own location (`bin/`) to find the parent directory. This means the project works from any clone path without editing scripts.
- **Menu bar app**: `ProjectLocator` walks up from the app bundle to find a directory containing `bin/activate-ai-window.sh`. For a standalone `.app`, it falls back to copying bundled scripts into Application Support and using that copy as the root.

The installer writes an absolute-path plist for macOS `launchd` and places it under `~/Library/LaunchAgents/`. The plist is intentionally git-ignored because it contains machine-specific paths.

### Project Structure

```text
activation-timer/
├── bin/
│   ├── activate-ai-window.sh   ← activation runner
│   └── activation-state.sh     ← JSON state for the app
├── scripts/
│   └── install-launchd.sh      ← launchd install/uninstall
├── app/
│   └── ActivationTimerMenuBar/ ← SwiftUI menu bar app
├── launchd/                    ← generated plist (git-ignored)
├── logs/                       ← generated logs
│   ├── activation.log
│   ├── usage.jsonl
│   ├── status.jsonl
│   └── raw/
├── .env.example
├── install.sh                  ← user-facing entry point
└── README.md
```

GitHub Actions only validates the repository scripts on push and pull requests. Scheduled activation always runs locally on the Mac where `./install.sh install` was executed.

## Cost Optimization

Each activation only needs a single API round-trip — the prompt and response together are under 300 tokens. The cost challenge is the **system prompt** that each CLI injects automatically (CLAUDE.md, plugins, MCP tool descriptions, hooks, etc.), which can exceed 40 000 tokens per call.

The runner strips both CLIs down to the absolute minimum context required:

### Claude

| Flag | Effect |
| --- | --- |
| `--model haiku` | Cheapest model (input ~$0.80/M vs Opus ~$15/M) |
| `--system-prompt "Reply only: READY"` | Custom minimal system prompt |
| `--setting-sources ""` | Skip loading CLAUDE.md, hooks, and plugin instructions — eliminates ~40K tokens of injected context |
| `--effort low` | Minimal reasoning effort |
| `--strict-mcp-config --mcp-config '{"mcpServers":{}}'` | Empty MCP config — removes all tool descriptions |
| `--tools ""` | Disable all built-in tools |
| `--disable-slash-commands` | Disable skills |

Result: **~170 input tokens, ~$0.001 per activation** (vs ~40K tokens / ~$0.15 without optimization).

### Codex

| Flag | Effect |
| --- | --- |
| `--ignore-user-config` | Skip `~/.codex/config.toml` — removes plugins, MCP servers, developer instructions |
| `--ignore-rules` | Skip `.rules` files |
| `-c 'features.memories=false'` | Disable memories |
| `-c 'features.multi_agent=false'` | Disable multi-agent |
| `-c 'features.goals=false'` | Disable goals |
| `-c 'features.codex_hooks=false'` | Disable hooks |
| `-c 'features.child_agents_md=false'` | Disable AGENTS.md loading |
| `-c 'model_reasoning_effort="low"'` | Minimal reasoning effort |

Result: **~22K input tokens** (vs ~32K without optimization). Codex's internal system prompt (~22K) is the floor — it cannot be stripped further, and ChatGPT accounts cannot switch to a lighter model.

### Monthly cost estimate (4 activations/day)

| Tool | Before | After |
| --- | --- | --- |
| Claude | ~$18/month | **~$0.16/month** |
| Codex | Quota-based, ~32K tokens/call | Quota-based, **~22K tokens/call (−31%)** |

## Safety Notes

- `dry-run` does not send model prompts.
- `quota` only queries account/rate-limit status paths and local caches; it does not send a model prompt.
- `run-now` and scheduled activation first run quota preflight, then send one small prompt per enabled tool only when quota appears available.
- If quota is known to be exhausted, the tool is skipped and recorded in `logs/usage.jsonl` with `skipped: true`.
- The Claude invocation uses `--model haiku`, `--setting-sources ""`, `--system-prompt`, `--effort low`, `--strict-mcp-config` with an empty config, no tools, no slash commands, and no session persistence. See [Cost Optimization](#cost-optimization) for details.
- The Codex invocation uses `--ephemeral`, `--skip-git-repo-check`, `--sandbox read-only`, `--ignore-user-config`, `--ignore-rules`, and disables features like memories, multi-agent, goals, and hooks.
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
