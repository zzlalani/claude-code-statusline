# Contributing

Thanks for helping out. This project is in beta, so small, focused changes are easiest to review.

## How to contribute

`main` is protected: nobody pushes to it directly, so every change comes in as a pull request.

1. **Fork** the repo and create a branch from `main`.
2. **Write the test first.** Add a failing case to `test.sh`, then make it pass.
3. Run the tests: `bash test.sh` (needs `bash` and `jq`).
4. Open a pull request. CI runs the tests on Linux and macOS, and both must pass.

Found a bug or have an idea? [Open an issue](../../issues/new/choose) first if it is a larger change.

## Guidelines

- Keep the script compatible with **bash 3.2** (the macOS default): no associative arrays, no `extglob` tricks.
- Keep pull requests small and about one thing.
- Use [conventional commits](https://www.conventionalcommits.org/): `feat:`, `fix:`, `docs:`, `chore:`, `test:`.
- Comment only the non-obvious *why*, not the *what*.
- Don't commit personal data. Screenshots and examples must use the `user@example.com` placeholder.
- `sync.sh` installs the script into your own `~/.claude`; you don't need it to contribute.

## Licence

By contributing you agree your work is released under the repository's [MIT licence](LICENSE).
