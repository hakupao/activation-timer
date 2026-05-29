# Changelog

All notable changes to this project will be documented in this file.

## 0.2.0 - 2026-05-29

### Menu bar app
- Rebuilt the menu bar app into a two-tab control panel: **Activity** and **Settings**.
- Activity dashboard: per-tool quota-trend chart (5-hour / weekly), a run-history timeline with expandable per-run details (tokens, cost, duration, session), summary stats (total / success / skipped / errors / average cost), and date-range / status / tool filters.
- Export run history to CSV.
- Bilingual in-app UI with an EN / 中 switch (previously only the documentation was bilingual).
- Appearance now follows the system Light/Dark setting instead of a fixed theme.
- Environment Check onboarding that detects required and optional CLI tools and shows install hints.
- In-app schedule editing with independent add/remove time points, per-tool enable toggles, and advanced options (quota preflight, post-run snapshots, keep-awake mode and duration, launch at login).
- The main window now comes to the front when opened from the menu.

### Fixes & reliability
- Fixed unreadable secondary text (dark-on-dark in Light mode) and the Quota Trend chart bleeding outside its card.
- Made activation timing reproducible across machines; runtime status checks are easier to discover.
- Skip prompts gracefully when a quota is already exhausted.
- Guarded `ProjectLocator` against an infinite directory walk; stabilized CI (pinned runner/Xcode/Homebrew, removed a deprecated Actions runtime).

### Internal
- Split the menu bar app into modular views (`MainView` / `ActivityView`) plus a `LogStore` core type.

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
