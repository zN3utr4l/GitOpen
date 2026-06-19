# Changelog (AI working log)

Chronological log of notable AI-assisted changes, newest first. Release history
lives in the root `CHANGELOG.md`; this is the working/tooling log.

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
