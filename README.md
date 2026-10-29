# claude-code-statusline

![status: beta](https://img.shields.io/badge/status-beta-orange) ![license: MIT](https://img.shields.io/badge/license-MIT-blue) ![shell: bash](https://img.shields.io/badge/shell-bash-lightgrey)

> **Beta.** Behaviour, thresholds and layout may change between commits. Not affiliated with or endorsed by Anthropic.

Claude Code status line: model with thinking effort, context usage, and 5-hour / 7-day rate-limit bars with reset countdowns.

```
Opus (high)                                                     user@example.com
ctx: █░░░░░░░ 12% (123k/1000k) | 5h: ████░░░░ 45% 4h18m | 7d: ██████░░ 80% 2d7h
```

## Install

Requires `bash` and `jq`.

One command (backs up your existing script and `settings.json`, and refuses to replace a different status line unless `STATUSLINE_FORCE=1`):

```sh
curl -fsSL https://raw.githubusercontent.com/zzlalani/claude-code-statusline/main/install.sh | bash
```

Or from a clone:

```sh
bash install.sh
```

Manual: copy `statusline-command.sh` to `~/.claude/` and add to `~/.claude/settings.json`:

```json
"statusLine": {
  "type": "command",
  "command": "bash ~/.claude/statusline-command.sh"
}
```

### Developing

To update the live copy after changing this project, run `bash sync.sh`. It runs the tests first, keeps the previous copy as `statusline-command.sh.bak`, and skips the copy if nothing changed. Set `STATUSLINE_TARGET` to install somewhere else.

## Colour thresholds

Each bar is coloured by % used. Below the first threshold it is green.

| Item | Blue from | Orange from | Red from | Blood red from |
|------|-----------|-------------|----------|----------------|
| ctx  | 30%       | 50%         | 70%      | 90%            |
| 5h   | 50%       | 70%         | 90%      | 100%           |
| 7d   | 80%       | 90%         | 95%      | 100%           |

| Tier      | 256-colour code |
|-----------|-----------------|
| Green     | 42              |
| Blue      | 39              |
| Orange    | 208             |
| Red       | 196             |
| Blood red | 124             |

Thresholds live in the `CTX_THRESHOLDS`, `FIVE_HOUR_THRESHOLDS` and `SEVEN_DAY_THRESHOLDS` constants at the top of `statusline-command.sh`.

## Notes

- The `(used/size)` token figure is the current context (input + cache tokens of the last call), so it matches the ctx percentage.
- The logged-in email (from `oauthAccount.emailAddress` in `~/.claude.json`) is right-aligned on the model line. The width follows the terminal (`COLUMNS`, minus a 17-column margin, since Claude Code crops the status line short of the full width), so it adapts on resize. If it doesn't fit next to the model name it moves to its own right-aligned line. Set `STATUSLINE_WIDTH` to force a fixed width. Nothing is shown if the file is missing.
- The ctx / 5h / 7d metrics are packed onto as few lines as fit the width and wrap onto further lines on narrow terminals.
- `LC_ALL=C` is forced so decimal-comma locales don't break percentage rounding.

## Test

```sh
bash test.sh
```

## Roadmap

- Install as a Claude Code plugin from a marketplace (planned).

## License

[MIT](LICENSE) © 2026 Zeeshan Lalani. You may use, modify, distribute and sell it, provided the copyright and licence notice are kept. It is provided as is, without warranty.
