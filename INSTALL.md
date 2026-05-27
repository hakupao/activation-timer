# Activation Timer Installation

Activation Timer is published in two forms.

## Beginner: menu bar app

1. Download `activation-timer-gui-<version>.dmg`.
2. Open the DMG and drag `Activation Timer.app` to `Applications`.
3. Open `Activation Timer.app`.
4. Click **Settings...** from the menu bar dropdown. Choose your schedule, tools, and other options. The app follows your system language; use the **EN/中** toggle in the top-right corner to switch.
5. Click **保存** (Save) to apply your settings and enable the schedule.
6. The status updates automatically — check the menu bar dropdown to confirm the schedule is on.

The app stores its working copy at:

```text
~/Library/Application Support/Activation Timer/activation-timer
```

Scheduled activation continues through macOS `launchd`, even when the app is not open.

If macOS warns that the app is from an unidentified developer, right-click
`Activation Timer.app`, choose **Open**, then confirm once. Future launches can
use the normal double-click path.

## Advanced: CLI / launchd

1. Download `activation-timer-cli-<version>.tar.gz`.
2. Extract it.
3. Copy `.env.example` to `.env`.
4. Run:

```sh
./install.sh check
./install.sh dry-run
./install.sh install
```

Useful commands:

```sh
./install.sh status
./install.sh quota
./install.sh run-now
./install.sh uninstall
```

To upgrade, replace the extracted folder with the new release, keep your `.env`,
then run `./install.sh install` again.

## Requirements

- macOS with `launchctl`.
- Authenticated Claude Code CLI and/or Codex CLI.
- `jq`.
- Node.js for Codex quota snapshots.
- `omc` for Claude quota snapshots.
