# Gotchas

Durable landmines. Read before editing or shipping.

## Tooling

- **`dart format` rewrites the whole repo.** The codebase predates the Dart 3.12
  tall-style formatter, so `dart format lib test` reformats ~180 files. Never
  blanket-format — format only files you touched, or do a dedicated chore PR.
- **`flutter analyze` is fatal on `info` and covers `test/`.** A long line in a
  test file fails CI. Always run bare `flutter analyze` (whole project) before
  pushing, not `flutter analyze <some files>`. Must run from the repo dir.
- **Regenerate drift code after schema changes:** `dart run build_runner build
  --delete-conflicting-outputs`. The schema includes a `folders` table
  (catalog + nested folders); checking out a branch that bumped the schema needs
  a codegen run before `flutter test`.

## Riverpod 3

- Legacy providers (`StateProvider`, `StateNotifierProvider`, `StateNotifier`)
  are **not** deprecated — they moved to `package:flutter_riverpod/legacy.dart`.
  Import that to use them without tripping the fatal analyzer.
- The v2 generated family type names are gone — let provider declarations infer
  their type; the unified v3 type is plain `FutureProvider<T>`. `analysis_options`
  disables `specify_nonobvious_*_types` for this reason.
- `AsyncValue.valueOrNull` was removed — use `.value` (now null-safe).
- `Override` for test `ProviderScope` helpers: import
  `package:flutter_riverpod/misc.dart`.

## Widgets / tests

- Any widget watching `appSettingsProvider` must override it in tests, or the
  default chain builds the real drift DB.
- `find.byTooltip` only counts laid-out rows in a lazy `ListView` — swapping an
  `IconButton` for an always-built `Tooltip` can surface a second match and break
  find-one assertions.
- Two real-git fixture tests can flake **only** under full-suite parallel load
  (they pass in isolation and in CI). If one fails, capture the output first.

## Git / CI / CD

- This is a **fork** of `samuu98/GitOpen`. Always pass `--repo zN3utr4l/GitOpen`
  to `gh` (otherwise PRs target the upstream). Never `git pull` without checking
  the tracking branch — `upstream/main` can trigger a large conflicting merge.
- `git log --format` with `%G?` forces GPG signature verification for every
  loaded commit. Keep it out of graph/fetch refresh paths unless the caller
  explicitly needs signatures (`verifySignature: true`). The graph should load
  without `%G?`; the commit details panel can verify only the selected commit.
- The PR gate (`flutter analyze` + `flutter test`, ubuntu-only) does **not**
  compile native runners or the Inno Setup installer — those run only in CD after
  merge. A broken `.iss` passes the PR green and fails CD post-merge. In `.iss`,
  escape literal `{` as `{{` (Inno treats `{` as a constant).
- Repo persistence across restarts/updates already exists (`main.dart`
  `_rehydrate()` + `WorkspacePersistence`); don't rebuild it.
- The `.git` watcher must ignore `index` and `*.lock`, and `git status` runs with
  `--no-optional-locks` — otherwise status rewrites `.git/index`, the watcher
  fires, and auto-refresh loops on busy repos.
