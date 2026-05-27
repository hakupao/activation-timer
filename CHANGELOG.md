# Changelog

All notable changes to this project will be documented in this file.

## 0.1.0 - 2026-05-27

- Initial macOS `launchd` activation scheduler.
- Added Claude Code and Codex low-cost activation runner.
- Added structured usage and quota snapshot logs.
- Added quota preflight so exhausted quotas are skipped and logged before prompts are sent.
- Added optional macOS menu bar app distribution that reuses the existing CLI/launchd engine.
- Added JSON app status output through `./install.sh app-status`.
- Added keep-awake settings backed by macOS `caffeinate`.
- Added release packaging for separate CLI and GUI artifacts.
- Added generated macOS app icon and beginner-focused installation docs.
- Added configurable `.env` support.
- Added English and Chinese documentation.
- Added validation script and GitHub Actions workflow.
