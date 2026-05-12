# GitOpen Slice 2 — Write/Sync Operations Design

- **Date:** 2026-05-12
- **Status:** Draft, pending user review
- **Author:** s.porta (with Claude Opus 4.7)
- **Supersedes for write ops:** §4.2 and §13 (slices 2 + 4) of the original
  `2026-05-08-gitopen-design.md`. This spec consolidates the daily-writes
  slice and a subset of the advanced-ops slice (merge, cherry-pick, clone)
  into a single deliverable.

## 1. Summary

Slice 2 adds the write side of git to GitOpen. After this slice the
application is usable as a daily git driver, not only a viewer.

**In scope:**
- Commit with **file-level and hunk-level staging**, amend, sign-off
- Branch ops: create (from HEAD or arbitrary commit), checkout, delete,
  rename
- Sync: fetch (single remote or all), pull (fast-forward / merge / rebase
  strategies), push (with `--force-with-lease`)
- Stash: save, pop, apply, drop, list
- Merge: fast-forward and 3-way with conflict detection; resolution via
  the user's external editor
- Cherry-pick (single commit) with abort/continue
- Clone from URL (HTTPS or SSH), with auth selection and progress
- Activity panel: toast + slide-in panel showing running and recent
  operations; persisted in drift
- Auth: PAT, SSH key path, legacy username/password, plus GitHub OAuth
  Device Flow; secrets stored in `flutter_secure_storage`
- Toolbar in title bar + context menus on commit / branch / tag / stash

**Explicitly out of scope (Slice 3+):**
- Interactive rebase (reorder/squash/edit-message)
- Revert
- Integrated 3-pane merge UI (resolution stays external)
- Submodules, LFS
- OAuth for GitLab / Bitbucket (PAT only)
- SSH key generation
- Auto-update, code signing

## 2. Technology Stack Additions

| New dependency | Purpose |
|---|---|
| `flutter_secure_storage` | OS keyring storage for auth secrets |
| `url_launcher` | Open browser for GitHub OAuth + open editor |
| `http` | GitHub OAuth Device Flow API calls |
| `process` (already in dart:io) | git CLI subprocess + progress parsing |

Existing stack (Flutter, Dart, drift, riverpod, bitsdojo_window) is
unchanged.

## 3. Architecture

### 3.1 New layer surface

```
lib/application/git/git_write_operations.dart        Interface + value types
lib/application/git/git_progress.dart                Progress event type
lib/application/auth/credentials_store.dart          Interface for secrets
lib/application/auth/auth_spec.dart                  AuthSpec sealed class
lib/application/operations/operations_provider.dart  Running ops StateNotifier
lib/application/operations/running_operation.dart    Op state record

lib/infrastructure/git/git_cli_write_operations.dart Implementation
lib/infrastructure/git/git_progress_parser.dart      stderr line → progress
lib/infrastructure/auth/secure_credentials_store.dart  flutter_secure_storage impl
lib/infrastructure/auth/github_device_flow.dart      OAuth Device Flow client
lib/infrastructure/persistence/tables/activity_log_table.dart

lib/ui/working_copy/working_copy_panel.dart          Replaces bottom panel when "Local Changes" selected
lib/ui/working_copy/file_list.dart                   Tri-state staged/unstaged with hunk children
lib/ui/working_copy/commit_compose.dart              Message + amend + sign-off + Commit / Commit & Push
lib/ui/conflicts/conflict_resolution_panel.dart      Detected during merge / cherry-pick
lib/ui/operations/toast_overlay.dart                 Bottom-right toast for current op
lib/ui/operations/activity_panel.dart                Slide-in full history
lib/ui/toolbar/toolbar.dart                          Fetch/Pull/Push/Branch/Stash row in title bar
lib/ui/dialogs/clone_dialog.dart                     URL + dest + auth picker
lib/ui/dialogs/auth_dialog.dart                      Prompt when push/pull fails on auth
lib/ui/dialogs/branch_create_dialog.dart             New branch name + base ref
lib/ui/menus/                                        Context-menu builders
lib/ui/settings/auth_settings.dart                   Manage saved credentials
```

### 3.2 Error model — Result types

```dart
sealed class GitResult<T> {
  const GitResult();
}

final class GitSuccess<T> extends GitResult<T> {
  final T value;
  const GitSuccess(this.value);
}

final class GitFailure<T> extends GitResult<T> {
  final GitErrorKind kind;
  final String message;
  final String? rawOutput;
  const GitFailure(this.kind, this.message, [this.rawOutput]);
}

enum GitErrorKind {
  network,            // remote unreachable, DNS, ssl
  auth,               // 401, key rejected
  conflict,           // merge / cherry-pick conflict
  nonFastForward,     // push rejected
  dirtyWorkingTree,   // checkout would lose changes
  unknownRef,         // bad branch / tag name
  invalidArgument,    // bad input from caller
  other,              // catch-all with raw output preserved
}
```

Callers pattern-match. Stream-based ops (fetch / pull / push / clone)
terminate the stream with `done` on success or emit a final
`GitProgress` with status `failed` before closing; the caller awaits the
stream and inspects the terminal event.

### 3.3 `GitWriteOperations` contract

```dart
abstract interface class GitWriteOperations {
  // Staging
  Future<GitResult<void>> stageFiles(RepoLocation r, List<String> paths);
  Future<GitResult<void>> unstageFiles(RepoLocation r, List<String> paths);
  Future<GitResult<void>> stagePatch(RepoLocation r, String unifiedDiff);
  Future<GitResult<void>> unstagePatch(RepoLocation r, String unifiedDiff);
  Future<GitResult<void>> discardChanges(RepoLocation r, List<String> paths);

  // Commit
  Future<GitResult<CommitSha>> commit(RepoLocation r, CommitRequest req);

  // Branch
  Future<GitResult<void>> createBranch(RepoLocation r, String name,
      {CommitSha? at, bool checkout = false});
  Future<GitResult<void>> checkout(RepoLocation r, String ref,
      {bool force = false});
  Future<GitResult<void>> deleteBranch(RepoLocation r, String name,
      {bool force = false, bool remote = false});
  Future<GitResult<void>> renameBranch(
      RepoLocation r, String oldName, String newName);
  Future<GitResult<void>> setUpstream(
      RepoLocation r, String branch, String upstream);
  Future<GitResult<void>> createTag(RepoLocation r, String name,
      {CommitSha? at, String? message});
  Future<GitResult<void>> deleteTag(RepoLocation r, String name);

  // Sync — stream emits GitProgress with terminal event signalling success / failure
  Stream<GitProgress> fetch(RepoLocation r,
      {String? remote, bool all = false});
  Stream<GitProgress> pull(RepoLocation r, PullStrategy strategy);
  Stream<GitProgress> push(RepoLocation r,
      {String? remote, String? branch, bool forceWithLease = false,
       bool pushTags = false});
  Stream<GitProgress> pushTag(RepoLocation r, String tagName,
      {String? remote});

  // Stash
  Future<GitResult<void>> stashSave(RepoLocation r, String message,
      {bool includeUntracked = false});
  Future<GitResult<void>> stashPop(RepoLocation r, int index);
  Future<GitResult<void>> stashApply(RepoLocation r, int index);
  Future<GitResult<void>> stashDrop(RepoLocation r, int index);

  // Merge
  Future<GitResult<MergeOutcome>> merge(RepoLocation r, String ref,
      {bool ffOnly = false, bool noCommit = false});
  Future<GitResult<void>> mergeAbort(RepoLocation r);
  Future<GitResult<CommitSha>> mergeContinue(RepoLocation r);

  // Cherry-pick
  Future<GitResult<CherryPickOutcome>> cherryPick(
      RepoLocation r, CommitSha sha);
  Future<GitResult<void>> cherryPickAbort(RepoLocation r);
  Future<GitResult<CommitSha>> cherryPickContinue(RepoLocation r);

  // Reset
  Future<GitResult<void>> reset(RepoLocation r, CommitSha to,
      ResetMode mode);

  // Clone — emits progress; the destination becomes a candidate workspace on success
  Stream<GitProgress> clone(String url, String destination,
      {AuthSpec? auth});
}

enum PullStrategy { ffOnly, merge, rebase }
enum ResetMode { soft, mixed, hard }
sealed class MergeOutcome { ... fastForward / merged / conflict ... }
sealed class CherryPickOutcome { ... applied / conflict ... }
```

`CommitRequest` carries message, amend flag, sign-off flag, optional
author override. `AuthSpec` is a sealed class with `HttpsPat`,
`HttpsBasic`, `Ssh`, `GitHubOauth`, `SystemDefault` variants.

## 4. Working Copy panel (commit UX)

A pseudo-row labelled **"Local Changes"** appears at the top of the
commit graph whenever `git status` reports any working-tree or index
entry. Selecting it replaces the bottom panel's commit-details with the
Working Copy panel.

### 4.1 Layout

Three vertical regions:

1. **File list** (top half): unstaged on top, staged below, with a
   collapsible "+12 -3" diff stat per file and per-file checkbox.
   Expanding a file reveals its hunks each with their own checkbox.
2. **Diff preview**: the currently focused file's unified diff,
   highlighted; hunks are visually grouped with their checkbox.
3. **Compose area** (bottom): multi-line textarea for the commit
   message, `Amend last commit` toggle (pre-fills with previous
   message), `Sign off` toggle (appends `Signed-off-by: name <email>`
   from `git config user.name`/`user.email`), and the action buttons
   `Commit` and `Commit & Push`.

### 4.2 Hunk-level staging

1. The panel loads `git diff` (unstaged) and `git diff --cached`
   (staged), reusing the existing diff parser.
2. UI maintains a `Set<HunkId>` of checked hunks per file.
3. On `Commit`: a unified-diff patch text is constructed from the
   checked hunks (taking the original hunk headers verbatim plus any
   user edits later — for Slice 2 edits are not supported, just
   selection).
4. The patch is piped through stdin to
   `git apply --cached --whitespace=nowarn`. On success, `git commit -m
   "<message>"` (plus flags) runs and the panel refreshes.
5. Untracked files: each is treated as a single virtual hunk with all
   additions; staging them runs `git add <path>` rather than
   `git apply`.
6. Binary files: checkbox-only at file level; no hunk children.

### 4.3 Discard

A `Discard` per-file action on unstaged entries runs
`git checkout -- <path>` (modified) or `rm <path>` (untracked), behind
a confirmation dialog because it is destructive.

## 5. Background operations: toast + activity panel

### 5.1 `RunningOperation` state record

```dart
final class RunningOperation {
  final String id;                   // uuid
  final OpKind kind;                 // fetch | pull | push | clone | merge | ...
  final String label;                // "Fetching origin"
  final RepoLocation? repo;          // null for clone
  final OperationStatus status;      // pending | running | success | failed | cancelled
  final double? progress;            // 0..1 or null for indeterminate
  final String phase;                // last phase reported by git
  final List<String> stderrTail;     // ring buffer, last 50 lines
  final DateTime startedAt;
  final DateTime? finishedAt;
  final Process? process;            // for cancellation
  final String? errorMessage;
}
```

### 5.2 `operationsProvider`

A `StateNotifierProvider<List<RunningOperation>>` exposes the live
list. Mutations only via `OperationsNotifier`:

```dart
class OperationsNotifier extends StateNotifier<List<RunningOperation>> {
  String start(OpKind k, String label, {RepoLocation? repo, Process? p});
  void updateProgress(String id, double? fraction, String phase);
  void appendStderr(String id, String line);
  void finishSuccess(String id);
  void finishFailure(String id, String message);
  void cancel(String id);
}
```

Each call also writes to the drift `activity_log` table (next section)
so the panel survives app restart.

### 5.3 Progress parsing

git CLI emits progress on stderr when invoked with `--progress`. Lines
look like:
```
remote: Counting objects:  45% (180/400)
Receiving objects:  23% (92/400)
Resolving deltas: 100% (40/40)
```

A `GitProgressParser` consumes the stderr stream line-by-line:
- Match `^(?<phase>[^:]+):\s+(?<pct>\d+)%`
- Update phase + fraction
- Lines without `%` are buffered as raw stderr

### 5.4 Toast widget

A `Positioned` overlay in the bottom-right corner of the shell:
- Shows the most-recent running op (or up to 3 stacked)
- Spinner + label + linear progress (or indeterminate dots)
- ✕ button to cancel
- Auto-dismiss 3s after success; persistent with red accent on failure
- Click → opens activity panel

### 5.5 Activity panel

Slide-in from the right edge. Sections:
- **Running** (current ops with cancel)
- **Recent** (last 50, success / failure / cancelled icons, filterable)
- `Clear completed` button

Each row expands to show full stderr buffer.

### 5.6 Persistence — `activity_log` drift table

```dart
class ActivityLog extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get opId => text()();
  TextColumn get kind => text()();          // OpKind.name
  TextColumn get label => text()();
  TextColumn get repoId => text().nullable()();
  TextColumn get status => text()();        // OperationStatus.name
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get finishedAt => dateTime().nullable()();
  TextColumn get stderr => text().nullable()();
  TextColumn get errorMessage => text().nullable()();
}
```

On startup, hydrate the in-memory list from the last 50 rows; any row
with status `running` is converted to `failed` ("interrupted by app
close") because the process is gone.

## 6. Auth & credentials

### 6.1 `AuthSpec` types

```dart
sealed class AuthSpec {
  const AuthSpec();
}
final class AuthHttpsPat extends AuthSpec {
  final String username;
  final String token;
}
final class AuthHttpsBasic extends AuthSpec {
  final String username;
  final String password;
}
final class AuthSsh extends AuthSpec {
  final String privateKeyPath;
  final String? passphrase;
}
final class AuthGitHubOauth extends AuthSpec {
  final String accessToken;
}
final class AuthSystemDefault extends AuthSpec {
  const AuthSystemDefault();
}
```

### 6.2 Storage

`flutter_secure_storage` keyed by remote host (`github.com`,
`gitlab.com`, `git.internal.novomatic.it`, …) or by full remote URL for
private servers without a clean host name.

Key format: `gitopen:auth:<host>` → JSON-encoded `AuthSpec` (token /
password fields encrypted by the OS keyring, not by us).

### 6.3 Injection into the `git` subprocess

- **HTTPS**: GitOpen ships a tiny embedded *credential helper* (a Dart
  entry point invoked with `--credential-helper-protocol`). We set the
  subprocess env var
  `GIT_TERMINAL_PROMPT=0` and
  `GIT_ASKPASS=<path-to-our-helper-exe-or-script>`
  for the call. The helper reads the request from stdin (git's standard
  credential protocol) and emits the credential from secure storage.
  Falls back to `<error>` if no credential is found, which git then
  surfaces as an auth failure, which our UI handles via the prompt
  dialog.
- **SSH**: set `GIT_SSH_COMMAND="ssh -i <key> -F /dev/null -o
  IdentitiesOnly=yes"` plus `SSH_ASKPASS` for the passphrase if any.
- **GitHub OAuth**: the access token is stored as if it were a PAT and
  injected via the same HTTPS helper.

### 6.4 Auto-prompt on auth failure

When any stream-based op terminates with `GitErrorKind.auth`, the UI
opens an `AuthDialog`:
- Title: `Authentication required for <host>`
- Tabs: `HTTPS token`, `SSH key`, `GitHub login` (visible only for
  `github.com`)
- Each tab has its own form
- `Save for this host` checkbox (default ON)
- On submit: store via secure storage, retry the operation

### 6.5 GitHub OAuth Device Flow

1. POST `https://github.com/login/device/code` with our client_id and
   `scope=repo`.
2. Response includes `device_code`, `user_code`,
   `verification_uri`, `expires_in`, `interval`.
3. UI displays the `user_code` and a copy button, plus opens the
   `verification_uri` in the user's browser via `url_launcher`.
4. Background poll loop hits
   `https://github.com/login/oauth/access_token` every `interval`
   seconds until response carries `access_token`.
5. Token saved as `AuthGitHubOauth` for `github.com`.

The `client_id` is a registered GitHub OAuth App owned by the project.
Per GitHub's docs, Device Flow does not require a client_secret, which
suits an open-source desktop app.

### 6.6 Settings UI

`Settings → Authentication` lists every stored credential with edit /
delete actions and a `Test` button that runs `git ls-remote` against
the host using that credential.

## 7. Conflict resolution flow

### 7.1 Detection

After any of merge / pull / cherry-pick, run `git status
--porcelain=v2`. Any entry whose code starts with `u ` indicates an
unmerged file. Presence of unmerged entries → enter conflict mode.

A `RepoState` notifier holds the current "operation in progress" flag
(`merge`, `cherryPick`, or `none`), inspected by reading
`.git/MERGE_HEAD`, `.git/CHERRY_PICK_HEAD`, or `.git/REBASE_HEAD`
sentinel files.

### 7.2 Conflict panel

When operation-in-progress != `none` and there are unmerged files, the
bottom panel switches to the Conflict Resolution view:

```
⚠ Merge in progress — 3 conflicts
  ⊗ src/foo.dart        [Open] [Mark resolved]
  ⊗ src/bar.dart        [Open] [Mark resolved]
  ⊗ docs/changelog.md   [Open] [Mark resolved]

[Show selected file's diff with <<<<<<< / ======= / >>>>>>> markers]

[Abort]                                        [Continue ✓]
```

- `Open` → launch the configured external editor with the file path.
- `Mark resolved` → `git add <path>`. When all conflicts are resolved,
  `Continue` is enabled.
- `Continue` → `git merge --continue` (or `--cherry-pick --continue`).
  Git prompts for a commit message; we run with `--no-edit` accepting
  the default merge message. Future iteration may add an inline
  textarea.
- `Abort` → `git merge --abort` / `cherry-pick --abort`.

### 7.3 External editor detection

Order:
1. `Settings → External editor` (custom path)
2. `$VISUAL` env var
3. `$EDITOR` env var
4. Heuristic: `code` (VS Code) → `subl` → `notepad++.exe` (Windows) →
   `gedit` (Linux)
5. Hard fallback: `notepad.exe` / `nano`

## 8. Clone flow

### 8.1 Entry points

- Repo dropdown: a `Clone repository...` entry between the workspace
  list and `Open repository...`.
- Welcome screen (when no workspaces open): `Clone` button alongside
  `Open`.

### 8.2 Dialog

- URL field (auto-detect host → suggests stored credentials if any)
- Destination folder picker (auto-fills the folder name from URL's
  basename minus `.git`)
- Auth selector: `<host> stored credential` / `Choose…` / `System
  default`
- `Open after clone` checkbox (default ON)
- `Clone` button → kicks off `git.clone(...)`, dialog closes, toast
  appears

### 8.3 During clone

Activity panel and toast as for any sync op. On success, if `Open after
clone` was checked, the destination is added as a workspace and
activated.

## 9. UI surface

### 9.1 Toolbar in title bar

Between the repo selector dropdown and the window controls:

```
[Fetch ▾] [Pull] [Push ▾]   [Branch ▾] [Stash ▾]
```

- **Fetch ▾**: Fetch <current upstream> (default), Fetch all remotes,
  Fetch tags only.
- **Pull**: pull with the current strategy preference (default
  `merge`). Long-press / right-click for `Pull (rebase)`,
  `Pull (ff-only)`.
- **Push ▾**: Push <current branch>, Push --force-with-lease, Push
  tags.
- **Branch ▾**: New branch from HEAD…, Switch branch…, Delete branch…,
  Rename current branch…
- **Stash ▾**: Stash changes, Apply latest, Pop latest, View stashes.

Each button is disabled when there is no active workspace, and shows a
spinner when its op is running.

### 9.2 Context menus

| Surface | Items |
|---|---|
| Commit row | Cherry-pick into current, Create branch here…, Tag here…, Copy SHA, Copy short SHA, Reset to here ▾ (soft/mixed/hard) |
| Local branch in sidebar | Checkout, Merge into current, Rename…, Delete, Push to <remote>, Set upstream… |
| Remote branch in sidebar | Checkout (creates tracking local), Merge into current, Delete from remote |
| Tag in sidebar | Checkout, Push tag, Delete tag |
| Stash in sidebar | Apply, Pop, Drop, View changes |

`Reset (hard)` and `Delete branch` go through a confirmation dialog
that lists what will be lost.

### 9.3 Keyboard shortcuts (Slice 2 — minimum set)

- `Ctrl+Enter` in commit textarea → Commit
- `Ctrl+Shift+Enter` in commit textarea → Commit & Push
- `Ctrl+R` → Refresh current view (re-run status / branches / graph)
- `Ctrl+T` → Open Repo selector dropdown
- `F5` → Fetch current remote

More mappings deferred.

## 10. Testing strategy

### 10.1 Unit + infrastructure

Continue the pattern from Slice 1: a `RepoFixture` seeds real temp git
repos and each write op runs against them. New fixture variants:
- `withConflict()`: two branches whose merge will conflict on a file
- `withMultipleRemotes()`: simulated by `git remote add` against
  local file:// URLs
- `withStashes(int n)`: pre-populates stash list

Test targets per area:
- `stageFiles` / `stagePatch` / `commit`: ~10 tests
- `createBranch` / `checkout` / `deleteBranch` / `renameBranch`: ~8
- `fetch` / `pull` / `push`: ~10 (using local file:// remotes)
- `stashSave/pop/apply/drop`: ~6
- `merge` (ff, 3-way clean, 3-way conflict, abort): ~6
- `cherryPick` (success, conflict, abort): ~4
- `clone`: ~3 (local file:// URL)
- `auth` Result wiring: ~5

Target: ~50 new tests on top of the existing 40 → ~90 total.

### 10.2 UI / widget tests

- Working Copy panel: file checkbox toggles correct staging
- Conflict panel renders correct file list, `Continue` enabled only
  when all resolved
- Toast appears on new op and disappears 3s after success

### 10.3 Manual smoke checklist

`docs/qa-checklist.md` extended with: clone a public repo, fetch /
pull / push on a real GitHub repo, stash flow, merge with conflict and
resolve via VS Code, cherry-pick a commit.

## 11. Risks and mitigations

| Risk | Mitigation |
|---|---|
| `git apply --cached` fails on whitespace-touching patches | Always pass `--whitespace=nowarn`; on failure surface raw stderr |
| OAuth Device Flow client_id leaks | Public on purpose for desktop apps using device flow; no client_secret needed |
| Long-running clone holds the UI scope alive | The Process is tracked in `RunningOperation`, not in a widget — survives navigation |
| Custom credential helper executable distribution | Ship as a Dart entry point invoked with `dart bin/credential_helper.dart` OR a small .exe built alongside the app. Decided at plan time. |
| `git merge --continue` opens an editor blocking the subprocess | Always invoke with `--no-edit` for now; revisit in Slice 3 |
| Cancelling a clone leaves a partial folder | After Process.kill, attempt `Directory(dest).delete(recursive: true)` best-effort |

## 12. Suggested implementation phasing

The plan (next document) will detail this; design-level guidance:

1. **Slice 2A — Foundation (~1 week)**: Result types, GitWriteOperations
   contract, OperationsNotifier + drift activity log + toast + activity
   panel, secure credentials store, AuthDialog.
2. **Slice 2B — Daily writes (~1.5 weeks)**: stage/unstage/commit with
   file-level only first, then hunk-level; branch create/checkout/
   delete/rename; status pseudo-row in graph + Working Copy panel.
3. **Slice 2C — Sync ops (~1 week)**: fetch / pull / push with progress
   parsing; auto-prompt auth dialog; GitHub OAuth Device Flow.
4. **Slice 2D — Stash + merge + cherry-pick + conflict UI (~1 week)**:
   stash CRUD; merge with conflict detection; cherry-pick; Conflict
   Resolution panel; reset.
5. **Slice 2E — Clone + toolbar polish + context menus (~0.5 week)**:
   clone dialog + flow; toolbar in title bar; context menus on commit,
   branch, tag, stash.

Each sub-slice ends in a buildable, manually-testable state. The plan
document will turn each into ~10-15 implementation tasks.

## 13. Open questions for the implementation plan

- Custom credential helper: standalone .exe vs Dart script invoked
  through Dart runtime
- Welcome-screen design when zero workspaces are open (visual layout)
- Exact strings for confirmation dialogs (Reset --hard, Delete branch,
  Discard changes)
- Persisted user preferences: default pull strategy, sign-off default
  on/off, external editor path

These are tactical and will be settled during planning.
