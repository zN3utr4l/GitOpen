# Changelog (AI working log)

Chronological log of notable AI-assisted changes, newest first. Release history
lives in the root `CHANGELOG.md`; this is the working/tooling log.

## 2026-06-19 — Post-v1.9.3 memory refresh

**Repo state**
- `main`/`origin/main` at `5a6d478`; app version `1.9.3+61`.
- Open PRs: 0 via `gh pr list --repo zN3utr4l/GitOpen --state open`.
- Merged/released in this session: #76 (GPG/fetch-to-graph perf) as v1.9.2;
  #75 (AI config + cleanup docs); #77 (select/copy diff text, changed-files
  list, collapsible file diffs) as v1.9.3.

**Durable gotchas added/confirmed**
- `%G?` in `git log --format` verifies every loaded commit; keep it out of
  graph/fetch refresh paths unless signatures are explicitly requested.
- Riverpod 3 test helpers that type provider overrides need
  `package:flutter_riverpod/misc.dart` for `Override`.
- `AsyncValue.valueOrNull` is gone in Riverpod 3; use `.value`.

## 2026-06-19 — AI config scheme + repo cleanup

**Cleanup**
- Removed stale planning docs: `docs/superpowers/plans/` (29) +
  `docs/superpowers/specs/` (24) + `docs/qa-checklist.md` — 54 files superseded
  by shipped features, git history, and the root `CHANGELOG.md`.
- Verified no dead code: 0 unreferenced Dart files (264 scanned) and
  `flutter analyze` clean. Cleared ~520 MB of local build artifacts
  (`build/`, `.dart_tool/`, `coverage/`).

**AI config scheme** (mirrors NE.GameServices, adapted to Flutter)
- Added `CLAUDE.md` + `AGENTS.md` (byte-for-byte copy).
- Added `.claude/settings.json` enabling the `frontend-design` plugin. No
  format-on-save hook on purpose: `dart format` would reformat the whole repo to
  the Dart 3.12 tall style.
- Added `.claude/memory/` — `MEMORY.md` (hub), `project-map.md`, `gotchas.md`,
  this `changelog.md`.
- No project skill (architecture conventions documented in `CLAUDE.md` +
  `project-map.md`).
