# Security Policy

## Supported versions
Stoker is a small utility released from `main`. Only the **latest released version** receives
fixes. Please reproduce issues on the most recent release before reporting.

## Reporting a vulnerability
Please **do not** open a public issue for security problems.

- Preferred: open a private report via GitHub →
  **[Security advisories](https://github.com/hakupao/stoker/security/advisories/new)**.
- Include: affected version, steps to reproduce, impact, and any logs (with secrets redacted).

You can expect an acknowledgement within a few days. Because this is a volunteer-maintained
project, fix timelines are best-effort.

## Scope and notes
- Stoker runs **entirely locally** and sends no data to the project authors. The only outbound
  traffic is the minimal prompts the Claude/Codex CLIs you configure send to their own services.
- The generated `launchd` plist and `.env` are **machine-specific and git-ignored**; never
  commit them.
- The macOS app is **ad-hoc signed, not notarized** — verify the source/build yourself if your
  threat model requires it.
- See [DISCLAIMER.md](DISCLAIMER.md) for trademark, warranty, and terms-of-service notices.
