[English](README.md) | [中文](README_CN.md)

# Activation Timer

> 一个很小的 macOS 定时器：按固定时间轻量触发 Claude Code 和 Codex，并记录触发日志、单次 usage、5 小时窗口和周额度状态。

[![CI](https://github.com/hakupao/activation-timer/actions/workflows/ci.yml/badge.svg)](https://github.com/hakupao/activation-timer/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

## 项目简介

Activation Timer 适合想把 Claude Code / Codex 用量窗口固定到自己作息时间的人。它通过 macOS `launchd` 定时运行，在一个专用轻量目录里让两个 CLI 只回复 `READY`，并明确要求不要扫描真实项目、不要运行工具、不要修改文件。

默认触发时间是本机时间 `07:00`、`12:00`、`17:00`、`22:00`。

## 功能

- 使用 macOS `launchd` 定时触发 Claude Code 和 Codex。
- 默认 prompt 极短，并要求不读文件、不运行工具、不修改内容。
- `logs/activation.log` 记录人类可读的运行历史。
- `logs/usage.jsonl` 记录每次真实触发返回的 token/usage 信息。
- `logs/status.jsonl` 记录 5 小时窗口和周额度快照。
- 真实触发前先检查额度；如果明确额度耗尽，会优雅跳过并记录日志。
- 通过 `.env` 配置时间、label、prompt、timeout 和工具路径。
- 支持 dry-run、依赖检查、只查额度、手动触发和卸载。

## 环境要求

- macOS 和 `launchctl`。
- Bash。
- 已登录的 Claude Code CLI。
- 已登录的 Codex CLI。
- `jq`：用于解析 JSONL 日志。
- Node.js：用于查询 Codex quota status。
- `omc` / oh-my-claudecode：用于查询 Claude quota status。

实际定时触发只依赖 Claude 和 Codex CLI；如果缺少 `omc`、`node` 或 `jq`，脚本会记录 warning 并跳过对应的结构化状态记录。

## 快速开始

```sh
git clone https://github.com/hakupao/activation-timer.git
cd activation-timer
cp .env.example .env
./install.sh check
./install.sh dry-run
./install.sh
```

`./install.sh` 默认执行 `install`，会生成 LaunchAgent 并加载到当前 macOS 用户的 GUI session。

## 常用命令

```sh
./install.sh check        # 检查本机依赖
./install.sh dry-run      # 只展示命令，不发送模型 prompt
./install.sh quota        # 只查询额度状态，不发送模型 prompt
./install.sh status       # 查看 launchd 状态
./install.sh run-now      # 手动真实触发一次，会发送模型 prompt
./install.sh uninstall    # 卸载 LaunchAgent
./install.sh print-plist  # 打印生成的 launchd plist
```

也可以直接调用 runner：

```sh
./bin/activate-ai-window.sh --once
./bin/activate-ai-window.sh --status
./bin/activate-ai-window.sh --once --tool claude
./bin/activate-ai-window.sh --once --tool codex
```

## 日常运行检查

用下面几条命令判断定时器是否已经安装、是否正在等待触发、以及上次运行结果：

```sh
./install.sh status
tail -f logs/activation.log
tail -n 20 logs/usage.jsonl | jq
tail -n 20 logs/status.jsonl | jq
```

`./install.sh status` 应该能看到已加载的 LaunchAgent，以及你配置的日历触发时间。两次触发之间显示 `state = not running` 是正常的，它表示任务已经加载，正在等待下一个定时点。真正触发的短时间内才可能显示 `running`。

`logs/activation.log` 是最适合日常看的文本日志。一次正常运行大致会像这样：

```text
Activation run started ...
Quota preflight started
Claude job started
Codex job started
Activation run finished exit=0
```

如果 quota preflight 判断额度已经耗尽，就不会发送 prompt，而是干净地记录跳过：

```text
claude job skipped by quota preflight reason=quota_exhausted
codex job skipped by quota preflight reason=quota_exhausted
```

`logs/usage.jsonl` 是结构化的成功/跳过记录。成功触发通常会包含 `ok: true`、`result: READY` 和 `exit_code: 0`。被跳过的触发会包含 `skipped: true` 和 `skip_reason`。

常用命令含义：

- `./install.sh status`：检查本地 `launchd` 是否已经加载定时器。
- `./install.sh quota`：只查额度状态，不发送 prompt。
- `./install.sh dry-run`：只打印计划执行的命令，不发送 prompt。
- `./install.sh run-now`：立刻触发已安装的 LaunchAgent；如果额度可用，可能消耗 usage。

## 配置

复制 `.env.example` 为 `.env`，按需修改：

| 变量 | 说明 | 默认值 |
| --- | --- | --- |
| `LABEL` | macOS LaunchAgent label | `com.activation-timer.ai-window` |
| `SCHEDULE_HOURS` | 逗号分隔的本地小时 | `7,12,17,22` |
| `SCHEDULE_MINUTE` | 所有触发时间共用的分钟 | `0` |
| `ACTIVATION_TOOL` | `all`、`claude` 或 `codex` | `all` |
| `ACTIVATION_PROMPT` | 发送给 CLI 的低消耗 prompt | `Reply exactly READY...` |
| `TIMEOUT_SECONDS` | 每个工具的超时时间 | `120` |
| `ENABLE_STATUS_SNAPSHOTS` | 真实触发后是否记录额度快照 | `1` |
| `ENABLE_QUOTA_PREFLIGHT` | 发送 prompt 前是否先检查额度 | `1` |
| `QUOTA_PREFLIGHT_ON_UNKNOWN` | 无法确认额度时 `allow` 继续或 `skip` 跳过 | `allow` |
| `QUOTA_EXHAUSTED_THRESHOLD_PERCENT` | 剩余额度低于或等于该百分比时跳过 | `0` |
| `CLAUDE_BIN` | Claude 路径覆盖 | 自动发现 |
| `CODEX_BIN` | Codex 路径覆盖 | 自动发现 |
| `JQ_BIN` | `jq` 路径覆盖 | 自动发现 |
| `NODE_BIN` | Node.js 路径覆盖 | 自动发现 |
| `OMC_BIN` | `omc` 路径覆盖 | 自动发现 |
| `PATH_VALUE` | launchd 和 runner 使用的 PATH | Homebrew/local/system 默认路径 |

修改时间或 label 后，重新安装一次：

```sh
./install.sh install
```

## 日志

```sh
tail -f logs/activation.log
tail -20 logs/usage.jsonl | jq
tail -20 logs/status.jsonl | jq
```

日志文件说明：

- `logs/activation.log`：人类可读的运行历史。
- `logs/usage.jsonl`：每个工具每次真实触发的 usage 快照。
- `logs/status.jsonl`：5 小时窗口和周额度快照。
- `logs/raw/`：Claude、Codex 和 status 查询的原始输出。
- `logs/launchd.out.log` / `logs/launchd.err.log`：launchd 的 stdout/stderr。

## 工作方式

```text
activation-timer/
├── bin/
│   └── activate-ai-window.sh
├── scripts/
│   └── install-launchd.sh
├── launchd/
│   └── 生成的 plist 文件
├── logs/
│   └── 生成的日志
├── .env.example
├── CHANGELOG.md
├── CONTRIBUTING.md
├── install.sh
├── LICENSE
├── README.md
└── README_CN.md
```

安装脚本会在运行时计算项目根目录，然后为 macOS `launchd` 生成带绝对路径的 plist，并安装到 `~/Library/LaunchAgents/`。runner 也会在运行时计算项目根目录，所以项目 clone 到别的位置后不需要手动改脚本路径。

GitHub Actions 只在 push 和 pull request 时校验仓库脚本。真正的定时触发始终运行在执行过 `./install.sh install` 的那台 Mac 本地。

## 安全说明

- `dry-run` 不会发送模型 prompt。
- `quota` 只查询账号/rate-limit 状态和本地 cache，不会发送模型 prompt。
- `run-now` 和定时触发会先做 quota preflight；只有额度看起来可用时，才给启用的工具发送一个很短的 prompt。
- 如果明确额度已经耗尽，对应工具会被跳过，并在 `logs/usage.jsonl` 里记录 `skipped: true`。
- Claude 默认禁用 slash commands、禁用 session persistence，并传入空 tools。
- Codex 默认使用 `--ephemeral`、`--skip-git-repo-check` 和 `--sandbox read-only`。
- 生成的 plist 会被 git 忽略，因为它包含本机绝对路径。

## 卸载

```sh
./install.sh uninstall
```

如果你从旧 label 迁移，可以安装时设置 `LEGACY_LABELS="old.label"`，这样旧 LaunchAgent 会被清理，避免重复触发。

## 参与贡献

提交修改前建议先运行：

```sh
./scripts/validate.sh
```

更多说明见 [CONTRIBUTING.md](CONTRIBUTING.md)。

## 更新记录

版本变化见 [CHANGELOG.md](CHANGELOG.md)。

## License

本项目使用 MIT License。详情见 [LICENSE](LICENSE)。
