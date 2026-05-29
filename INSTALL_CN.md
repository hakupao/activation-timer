# Stoker 安装方式

Stoker 会发布成两种形态。

## 小白初学者：菜单栏 App

1. 下载 `stoker-gui-<version>.dmg`。
2. 打开 DMG，把 `Stoker.app` 拖到 `Applications`。
3. 打开 `Stoker.app`。
4. 点击菜单栏下拉中的 **设置...**，选择运行时间、工具和其他选项。
5. 点击 **保存** 应用设置并开启定时。
6. 打开菜单栏下拉，状态会自动刷新，确认定时器已开启。

App 会把工作副本放在：

```text
~/Library/Application Support/Stoker/stoker
```

定时触发仍然由 macOS `launchd` 执行，所以 App 关闭后，已经安装的 schedule 也会继续生效。

如果 macOS 提示 App 来自未识别开发者，右键点击 `Stoker.app`，
选择 **打开**，再确认一次。之后就可以正常双击打开。

## IT 高手：CLI / launchd

1. 下载 `stoker-cli-<version>.tar.gz`。
2. 解压。
3. 复制 `.env.example` 为 `.env`。
4. 运行：

```sh
./install.sh check
./install.sh dry-run
./install.sh install
```

常用命令：

```sh
./install.sh status
./install.sh quota
./install.sh run-now
./install.sh uninstall
```

升级时，把新版本解压后替换旧目录，保留自己的 `.env`，然后重新运行
`./install.sh install`。

## 环境要求

- macOS 和 `launchctl`。
- 已登录的 Claude Code CLI 和/或 Codex CLI。
- `jq`。
- Node.js：用于 Codex quota 快照。
- `omc`：用于 Claude quota 快照。
