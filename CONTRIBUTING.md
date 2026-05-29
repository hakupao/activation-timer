# Contributing

Thanks for improving Stoker.

## Local Checks

Before opening a pull request, run:

```sh
./scripts/validate.sh
```

This checks shell syntax, validates generated launchd plist output on macOS,
and verifies the safe dry-run path.

## Development Notes

- Keep the default activation prompt tiny and explicit.
- Do not add dependencies unless they are needed for reliability.
- Do not commit generated logs, `.env`, `.omx`, `.omc`, `run/`, or generated plist files.
- Keep `run-now` clearly marked as a real usage-consuming action.
- Prefer portable Bash and macOS built-ins where possible.

## Commit Style

Use clear commit messages that explain why the change exists. If a change
affects scheduling, quota logging, or account state, include verification notes
in the commit body.

