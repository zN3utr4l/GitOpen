# GitOpen — AI Project Memory

Persistent memory for AI assistants working in this repo. Keep it short and
current; move detail into the linked files.

## Workflow rules

- Read [project-map.md](project-map.md) before navigating the code, and
  [gotchas.md](gotchas.md) before editing or shipping.
- `main` is PR-gated: branch → push → PR → green `build-and-test (ubuntu-latest)`
  → merge. Bump `pubspec.yaml` version when `lib/` changes.
- Run bare `flutter analyze` (whole project, fatal on `info`) and `flutter test`
  before pushing. Do **not** blanket-`dart format`.
- Commit as **zN3utr4l**; `gh` commands need `--repo zN3utr4l/GitOpen` (fork).

## Current state (2026-06-19)

- `main` is synced with `origin/main` at `5a6d478`; `pubspec.yaml` is
  `version: 1.9.3+61`.
- Open PRs: none (`gh pr list --repo zN3utr4l/GitOpen --state open` returned
  no rows on 2026-06-19).
- Recently merged: #75 AI config + repo cleanup; #76 GPG/fetch-to-graph
  performance fix released as v1.9.2; #77 selectable/copyable diffs,
  changed-files list, and collapsible file diffs released as v1.9.3.

## Project identity

- Cross-platform (Windows/Linux) desktop **git client** in Flutter/Dart.
- Wraps the system `git` CLI for all operations (no libgit2).
- Clean architecture: `domain` / `application` / `infrastructure` / `ui`.
- Riverpod 3 (state) · drift/SQLite (persistence) · bitsdojo_window (chromeless).

## Quick reference

| Task | Command |
|------|---------|
| Run (Windows) | `.\run.ps1` or `flutter run -d windows` |
| Run (Linux) | `flutter run -d linux` |
| Test | `flutter test` |
| Analyze | `flutter analyze` (from repo dir) |
| Codegen (drift) | `dart run build_runner build --delete-conflicting-outputs` |
| Build Windows | `flutter build windows --release` |
| Build Linux .deb | `bash scripts/build-deb.sh` |

## Index

- [project-map.md](project-map.md) — module/layer map of `lib/`
- [gotchas.md](gotchas.md) — tooling, Riverpod, test, and CI/CD landmines
- [changelog.md](changelog.md) — AI working log of notable changes
