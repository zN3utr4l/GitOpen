# Project Map

Layered Flutter app. ~264 Dart files in `lib/` across four layers.

## `lib/domain/` — pure types (no I/O)
- `commits/` — `CommitInfo`, `CommitSha`, `CommitSignature`, `GpgSignatureStatus`
- `diff/` — `DiffResult`, `DiffHunk`, `DiffLine`, `FileDiff`, `MergeConflict`, `DiffSpec`
- `refs/` — `Branch`, `Remote`, `Tag`, `Stash`, `Submodule`, `Worktree`, `ReflogEntry`
- `status/` — `RepoStatus`, `WorkingFileEntry`
- `files/` — `FileContent`, `FileRevision`, `FileTreeEntry`
- `repositories/` — `RepoId`, `RepoLocation`, `Folder`, `FolderId`
- `blame/` — `BlameLine`

## `lib/application/` — use cases, providers, ports (pure; no `dart:io`)
- `git/` — `GitActionsService`, read/write operation ports, `GitResult`,
  `RebasePlan`, `MergeOutcome`, `BranchDeletion`, `AuthFailureClassifier`
- `auth/` — `AuthResolver`, `AuthProfile(Store)`, `DeviceFlowController`,
  `CredentialTester`, `AccountEmails`
- `github/` — `GitHubApi` port, models, PR diff, slug
- `git_lfs/`, `git_identity/`, `commit_graph/` (layout), `diff/` (patch builders,
  intraline, split), `workspaces/` (registry, tree, persistence), `watch/`
  (`RepoWatcher`, `Debouncer`, `RepoChange`), `settings/`, `updates/`,
  `operations/`, `launcher/`, `files/`
- **`providers.dart`** — composition root; the only place `dart:io` is wired in.

## `lib/infrastructure/` — adapters (`dart:io` lives here)
- `git/` — `GitProcessRunner`, CLI readers/writers (status/log/ref/file/sync/
  sequencer/worktree), parsers (diff/blame/progress), `credential_helper`
- `github/` — `GitHubRestApi`
- `auth/` — DPAPI storage, GitHub device flow / user service
- `persistence/` — drift `database.dart`, `tables/`, repository impls
- `watch/` — `IoRepoWatcher`; `launcher/`, `logging/`, `updates/`, `git_lfs/`

## `lib/ui/` — Flutter widgets
- `shell/`, `toolbar/`, `sidebar/`, `commit_graph/`, `working_copy/`,
  `bottom_panel/` (diff/commit details/file tree), `github/` (PRs + Actions),
  `lfs/`, `conflicts/`, `dialogs/`, `settings/sections/`, `command_palette/`,
  `operations/` (toasts/overlays), `common/` (shared primitives), `theme/`
  (`app_design_tokens.dart`, `app_palette.dart`), `welcome/`, `status_bar/`,
  `auto_refresh/`

## Entry point
- `lib/main.dart` — app bootstrap, rehydrate saved repos, Shortcuts/Actions.

## Persistence
drift SQLite DB under `getApplicationSupportDirectory()`
(`%APPDATA%\GitOpen\GitOpen\...`). Tables: `repositories`, `folders`,
`settings`, `activity_log`.
