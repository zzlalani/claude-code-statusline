# Changelog

All notable changes to this project are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow [Semantic Versioning](https://semver.org/).

## [0.1.0] - 2026-11-25

### Added

- Status line showing model, thinking effort, context usage bar, and 5h / 7d rate-limit bars with reset countdowns.
- Metrics wrap greedily across lines on narrow terminals; the account email right-aligns or moves to its own line.
- One-command installer.
- CI test workflow on Ubuntu and macOS (bash 3.2).

### Fixed

- Bars on stacked lines no longer merge into one block when the status line wraps.

[0.1.0]: https://github.com/zzlalani/claude-code-statusline/releases/tag/v0.1.0
