# Disclaimer & Legal Notices

[English](#english) · [中文](#中文)

## English

### No affiliation
Stoker is an **independent, open-source project**. It is **not affiliated with, authorized by,
endorsed by, or sponsored by** Anthropic, OpenAI, Apple, or any other company. It is not an
official product of any of them.

### Trademarks
"Claude", "Claude Code", and "Anthropic" are trademarks of Anthropic, PBC. "Codex", "ChatGPT",
and "OpenAI" are trademarks of OpenAI. "macOS" and "Apple" are trademarks of Apple Inc. All
other trademarks are the property of their respective owners. These names are used in this
project **only to identify the tools Stoker interoperates with** (nominative use); no
affiliation or endorsement is implied.

### No warranty
Stoker is provided **"as is", without warranty of any kind**, express or implied, including but
not limited to the warranties of merchantability, fitness for a particular purpose, and
non-infringement. You use it **at your own risk**. See [LICENSE](LICENSE) (MIT) for the full
terms.

### Your responsibility for third-party terms of service
Stoker sends automated, low-cost "check-in" prompts to the **Claude Code** and **Codex** CLIs
on your behalf, at times you schedule, to keep your usage windows active.

**You are solely responsible** for ensuring that this use complies with the applicable Terms of
Service, usage policies, acceptable-use policies, and rate limits of Anthropic and OpenAI (and
of whatever subscription plan you hold). Automated activation may not be permitted under those
terms — review them before using Stoker. The authors and contributors accept **no
responsibility** for any rate-limiting, billing, account limitation, suspension, or other
consequence arising from your use of this software.

### Costs and quota
Real activations consume API usage, credits, or plan quota and **may incur charges**. You are
responsible for monitoring your own usage and costs. Use `./install.sh dry-run` and
`./install.sh quota` to inspect what would be sent and your current status **without** sending
any model prompt.

### Privacy and data
Stoker runs **entirely on your own Mac**. It does **not** collect, transmit, or share your data
with the project authors or any third party. The only outbound network activity is the minimal
prompts that the **Claude/Codex CLIs you configure** send to their own services. Activation,
usage, and quota logs are written **locally** under `logs/` and never leave your machine.

### Distribution and code signing
The macOS menu bar app is **ad-hoc signed and not notarized by Apple**. macOS will therefore
require a one-time manual approval on first launch (see [INSTALL.md](INSTALL.md)). If you prefer,
you can review and build the app yourself from source.

### Third-party software
The GUI app bundles the [`jq`](https://github.com/jqlang/jq) binary (© 2012 Stephen Dolan and
contributors), used for JSON parsing and redistributed under its MIT license. All credit for
`jq` goes to its authors.

---

## 中文

### 无隶属关系
Stoker 是一个**独立的开源项目**，与 Anthropic、OpenAI、Apple 或任何其他公司**没有隶属关系，
也未获得其授权、认可或赞助**，不是上述任何一方的官方产品。

### 商标
"Claude"、"Claude Code"、"Anthropic" 是 Anthropic, PBC 的商标；"Codex"、"ChatGPT"、"OpenAI"
是 OpenAI 的商标；"macOS"、"Apple" 是 Apple Inc. 的商标。其余商标归各自所有者所有。本项目使用
这些名称**仅为标识 Stoker 所配合的工具**（指明性使用），不暗示任何隶属或背书关系。

### 不提供担保
Stoker 按**"现状"（as is）提供，不附带任何明示或默示的担保**，包括但不限于适销性、特定用途
适用性和不侵权的担保。使用风险由你自行承担。完整条款见 [LICENSE](LICENSE)（MIT）。

### 第三方服务条款由你负责
Stoker 会在你设定的时间，代表你向 **Claude Code** 和 **Codex** CLI 发送极低成本的「打卡」
prompt，以保持用量窗口活跃。

**你需自行负责**确保此种使用符合 Anthropic 与 OpenAI（以及你所订阅套餐）的服务条款、使用政策、
可接受使用政策与速率限制。自动触发**未必**被上述条款允许——使用前请自行查阅。对于因使用本软件
导致的限流、计费、账号受限、封禁或其他后果，作者与贡献者**概不负责**。

### 费用与额度
真实触发会消耗 API 用量 / 额度 / 套餐配额，并**可能产生费用**。你需自行监控自己的用量与花费。
可用 `./install.sh dry-run` 和 `./install.sh quota` 在**不发送**任何模型 prompt 的前提下，查看
将要发送的内容和当前状态。

### 隐私与数据
Stoker **完全在你本机运行**，**不会**向项目作者或任何第三方收集、传输或共享你的数据。唯一的对外
网络行为，是**你所配置的 Claude/Codex CLI** 向其自家服务发送的极简 prompt。触发、用量与额度日志
都**只写在本地** `logs/` 目录，绝不离开你的机器。

### 分发与代码签名
菜单栏 App 为 **ad-hoc 签名、未经 Apple 公证（notarize）**，因此 macOS 首次打开会要求你手动放行
一次（见 [INSTALL_CN.md](INSTALL_CN.md)）。你也可以自行审阅源码并从源码构建。

### 第三方软件
GUI App 内置了 [`jq`](https://github.com/jqlang/jq) 二进制（© 2012 Stephen Dolan 及贡献者），
用于解析 JSON，依据其 MIT 许可证一并分发。`jq` 的全部功劳归其作者所有。
