# Contributing

GitOpen is open source under the MIT license. Contributions welcome.

## Development setup

See `README.md`. Run `dotnet test` before submitting a PR.

## Architecture

See `docs/superpowers/specs/` for the design and `docs/superpowers/plans/` for
slice-by-slice implementation plans.

## Conventions

- TDD on Application and Infrastructure layers; bUnit on UI components.
- Conventional Commits (`feat:`, `fix:`, `docs:`, `test:`, `chore:`, `ci:`).
- One logical change per commit.
- Keep files focused: one responsibility per file.
