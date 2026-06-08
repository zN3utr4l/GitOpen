# Slice 0 — Fork Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stand up a stable, properly-attributed `zN3utr4l/GitOpen` fork with green CI, fix the two known bugs (empty merge-commit diff, locale-dependent error classification), and adopt `very_good_analysis` linting.

**Architecture:** Pure-additive foundation work. Bug 1 is a one-line git-flag change in the diff reader (`--first-parent -m`, verified to work for merge, normal, and root commits). Bug 2 introduces a single DRY env-builder (`buildGitEnvironment`) forcing `LC_ALL=C`/`LANG=C`, wired into every git subprocess. Identity changes are text/config. Lint is config + mechanical `dart fix` + residual cleanup.

**Tech Stack:** Flutter/Dart, `flutter_test`, git CLI driven via `dart:io`, `drift` (codegen via `build_runner`), `gh` CLI for fork/CI.

**Working copy:** `D:\repos\Personal\GitOpen` (currently `origin` = upstream `samuu98/GitOpen`). Branch: `slice0-foundation` (spec already committed here).

**Important environment facts:**
- `gh` is authenticated with TWO accounts; the **active one is `giuseppe-chirico`**. The fork MUST go to `zN3utr4l` → switch active account first (Task 0).
- Generated `*.g.dart` files are **gitignored** → `dart run build_runner build` is required locally before `flutter analyze`/`flutter test`.
- `.github/workflows/release.yml` is **repo-agnostic** (uploads via `softprops/action-gh-release` to the current repo, no hardcoded owner) → **no change needed**. The only wrong repo reference is the updater default (`s-porta/gitopen`).

---

## File Structure

| File | Responsibility | Action |
|------|----------------|--------|
| `test/_helpers/repo_fixture.dart` | Test git-repo fixtures | Modify — add `withMergeCommit()` |
| `test/infrastructure/git/git_cli_read_operations_diff_test.dart` | Diff reader tests | Modify — add merge-diff test |
| `lib/infrastructure/git/git_cli_read_operations.dart` | Git read ops | Modify — `getDiff` merge flags |
| `test/infrastructure/git/git_process_runner_env_test.dart` | Env builder test | Create |
| `lib/infrastructure/git/git_process_runner.dart` | Git subprocess runner | Modify — add `kGitLocaleEnv` + `buildGitEnvironment`, wire env |
| `lib/infrastructure/git/git_cli_write_operations.dart` | Git write ops (direct `Process` calls) | Modify — locale env on all 6 call sites |
| `LICENSE` | License/attribution | Modify — add fork copyright |
| `README.md` | Docs | Modify — fork section |
| `lib/ui/settings/sections/about_section.dart` | About UI | Modify — maintainer line |
| `lib/infrastructure/updates/github_release_updater.dart` | Update checker | Modify — owner/repo defaults |
| `pubspec.yaml` | Deps | Modify — add `very_good_analysis` |
| `analysis_options.yaml` | Lint config | Modify — adopt `very_good_analysis` + excludes |

---

## Task 0: Fork, remotes, CI, and green baseline

**Files:** none (git/gh/CLI setup)

> ⚠️ The fork is a public, outward-facing action. Confirm `zN3utr4l` with the user before running step 2.

- [ ] **Step 1: Switch the active gh account to the fork owner**

```bash
gh auth switch --user zN3utr4l
gh auth status   # verify: "Active account: true" under zN3utr4l
```

- [ ] **Step 2: Fork upstream to zN3utr4l (no clone — we already have a working copy)**

```bash
gh repo fork samuu98/GitOpen --clone=false
```
Expected: `✓ Created fork zN3utr4l/GitOpen`

- [ ] **Step 3: Repoint remotes in the existing working copy**

```bash
cd /d/repos/Personal/GitOpen
git remote rename origin upstream
git remote add origin https://github.com/zN3utr4l/GitOpen.git
git fetch origin
git remote -v
```
Expected: `origin` → `zN3utr4l/GitOpen`, `upstream` → `samuu98/GitOpen`.

- [ ] **Step 4: Enable GitHub Actions on the fork**

```bash
gh api -X PUT repos/zN3utr4l/GitOpen/actions/permissions -F enabled=true -f allowed_actions=all
```
Expected: HTTP 204. (If it errors, enable manually at `https://github.com/zN3utr4l/GitOpen/settings/actions`.)

- [ ] **Step 5: Local build + green baseline (BEFORE any change)**

```powershell
cd D:\repos\Personal\GitOpen
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test
```
Expected: `flutter analyze` → "No issues found!"; `flutter test` → all pass. This is the baseline; if anything fails here, STOP and report (the fork must start from green).

- [ ] **Step 6: Push the branch to the fork**

```bash
git push -u origin slice0-foundation
```
Expected: branch published on `origin` (the fork).

---

## Task 1: Bug 1 — merge-commit diff against first parent (TDD)

**Files:**
- Modify: `test/_helpers/repo_fixture.dart`
- Test: `test/infrastructure/git/git_cli_read_operations_diff_test.dart`
- Modify: `lib/infrastructure/git/git_cli_read_operations.dart:678-692` (`getDiff`)

- [ ] **Step 1: Add a merge-commit fixture**

In `test/_helpers/repo_fixture.dart`, add this method to the `RepoFixture` class (after `withBranches()`, before `dispose()`):

```dart
  /// Repo whose HEAD is a real (`--no-ff`) merge commit with two parents.
  /// `master` adds master.txt, `feature` adds feature.txt; the merge
  /// introduces feature.txt relative to its FIRST parent (master).
  static Future<RepoFixture> withMergeCommit() async {
    final f = await empty();
    await File(p.join(f.path, 'file_0.txt')).writeAsString('content 0\n');
    await _git(f.path, ['add', 'file_0.txt']);
    await _git(f.path, ['commit', '-q', '-m', 'commit 0']);

    await _git(f.path, ['checkout', '-q', '-b', 'feature']);
    await File(p.join(f.path, 'feature.txt')).writeAsString('feature\n');
    await _git(f.path, ['add', 'feature.txt']);
    await _git(f.path, ['commit', '-q', '-m', 'on feature']);

    await _git(f.path, ['checkout', '-q', 'master']);
    await File(p.join(f.path, 'master.txt')).writeAsString('master\n');
    await _git(f.path, ['add', 'master.txt']);
    await _git(f.path, ['commit', '-q', '-m', 'on master']);

    await _git(f.path, ['merge', '-q', '--no-ff', '-m', 'merge feature', 'feature']);
    f.headSha = (await _git(f.path, ['rev-parse', 'HEAD'])).trim();
    return f;
  }
```

- [ ] **Step 2: Write the failing test**

In `test/infrastructure/git/git_cli_read_operations_diff_test.dart`, add inside the `group('GitCliReadOperations.getDiff', ...)` block:

```dart
    test('merge commit diffs against first parent (not empty)', () async {
      final f = await RepoFixture.withMergeCommit();
      try {
        final sut = GitCliReadOperations();
        final diff = await sut.getDiff(
            loc(f), DiffSpecCommitVsParent(CommitSha(f.headSha)));
        final feature = diff.files.where((d) => d.path == 'feature.txt');
        expect(feature, hasLength(1));
        expect(feature.first.changeKind, FileChangeKind.added);
        expect(feature.first.hunks, isNotEmpty);
      } finally {
        await f.dispose();
      }
    });
```

- [ ] **Step 3: Run the test — verify it FAILS**

```powershell
flutter test test/infrastructure/git/git_cli_read_operations_diff_test.dart --plain-name "merge commit diffs against first parent"
```
Expected: FAIL — `feature` is empty (`Expected: an object with length of <1>` / `Actual: <0>`), because `git show <merge> --raw -p` emits a combined diff (`diff --cc`) the parser doesn't read.

- [ ] **Step 4: Implement the fix**

In `lib/infrastructure/git/git_cli_read_operations.dart`, change the `DiffSpecCommitVsParent` arm of the `switch (spec)` in `getDiff` from:

```dart
      DiffSpecCommitVsParent(:final commitSha) => [
          'show', commitSha.value, '--format=', '--raw', '-p', '--no-color',
        ],
```
to:

```dart
      DiffSpecCommitVsParent(:final commitSha) => [
          // `--first-parent -m` makes merge commits emit a normal 2-way diff
          // against their first parent (Fork/GitKraken default) instead of a
          // combined diff the unified parser can't read. No-op on normal and
          // root commits, so it's safe for all single-commit diffs.
          'show', commitSha.value, '--first-parent', '-m',
          '--format=', '--raw', '-p', '--no-color',
        ],
```

- [ ] **Step 5: Run the new test + the whole diff suite — verify PASS**

```powershell
flutter test test/infrastructure/git/git_cli_read_operations_diff_test.dart
```
Expected: PASS — the new merge test passes, and the existing "commit vs parent" and "initial commit (no parent)" tests still pass (verified: `--first-parent -m` is a no-op on those).

- [ ] **Step 6: Commit**

```bash
git add test/_helpers/repo_fixture.dart test/infrastructure/git/git_cli_read_operations_diff_test.dart lib/infrastructure/git/git_cli_read_operations.dart
git -c commit.gpgsign=false commit -m "$(cat <<'EOF'
fix(diff): show merge commits vs first parent

git show on a merge emitted a combined diff (diff --cc / @@@) the
unified parser ignored, producing an empty diff. --first-parent -m
yields a normal 2-way diff vs the first parent; verified no-op on
normal and root commits.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: Bug 2 — force C locale on all git subprocesses (TDD)

**Files:**
- Create: `test/infrastructure/git/git_process_runner_env_test.dart`
- Modify: `lib/infrastructure/git/git_process_runner.dart`
- Modify: `lib/infrastructure/git/git_cli_write_operations.dart` (6 direct `Process` call sites)

- [ ] **Step 1: Write the failing test**

Create `test/infrastructure/git/git_process_runner_env_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:gitopen/infrastructure/git/git_process_runner.dart';

void main() {
  group('buildGitEnvironment', () {
    test('forces the C locale', () {
      final env = buildGitEnvironment();
      expect(env['LC_ALL'], 'C');
      expect(env['LANG'], 'C');
    });

    test('merges extra env without dropping the locale', () {
      final env = buildGitEnvironment({'GIT_TERMINAL_PROMPT': '0'});
      expect(env['GIT_TERMINAL_PROMPT'], '0');
      expect(env['LC_ALL'], 'C');
      expect(env['LANG'], 'C');
    });

    test('locale always wins over a conflicting extra value', () {
      final env = buildGitEnvironment({'LC_ALL': 'it_IT.UTF-8'});
      expect(env['LC_ALL'], 'C');
    });
  });
}
```

- [ ] **Step 2: Run the test — verify it FAILS**

```powershell
flutter test test/infrastructure/git/git_process_runner_env_test.dart
```
Expected: FAIL to COMPILE — `buildGitEnvironment` is undefined.

- [ ] **Step 3: Add the env builder**

In `lib/infrastructure/git/git_process_runner.dart`, add at top level (after the imports, before `class GitProcessException`):

```dart
/// Locale forced on every git subprocess so stdout/stderr messages are
/// always parseable English, regardless of the host system locale. The
/// error classifier matches English substrings, so this keeps it
/// deterministic on non-English machines.
const Map<String, String> kGitLocaleEnv = {'LC_ALL': 'C', 'LANG': 'C'};

/// Merges caller-supplied [extra] env (e.g. credential-helper vars) with
/// the forced C locale. Locale keys are applied last so they always win.
Map<String, String> buildGitEnvironment([
  Map<String, String> extra = const {},
]) =>
    {...extra, ...kGitLocaleEnv};
```

- [ ] **Step 4: Run the test — verify PASS**

```powershell
flutter test test/infrastructure/git/git_process_runner_env_test.dart
```
Expected: PASS (all 3).

- [ ] **Step 5: Wire the locale into `GitProcessRunner`'s three methods**

In `lib/infrastructure/git/git_process_runner.dart`, add `environment: buildGitEnvironment(),` to each `Process.run`/`Process.start`:

In `run` (the `Process.run(...)` call), add the `environment` arg:
```dart
    final result = await Process.run(
      executable,
      args,
      workingDirectory: workingDir,
      environment: buildGitEnvironment(),
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    );
```

In `runWithStdin` (the `Process.start(...)` call):
```dart
    final proc = await Process.start(executable, args,
        workingDirectory: workingDir, environment: buildGitEnvironment());
```

In `streamLines` (the `Process.start(...)` call):
```dart
    final p = await Process.start(executable, args,
        workingDirectory: workingDir, environment: buildGitEnvironment());
```

- [ ] **Step 6: Wire the locale into the 6 direct `Process` calls in write ops**

In `lib/infrastructure/git/git_cli_write_operations.dart`:

**(a)** In `_runProgressStream`, change:
```dart
        environment: helper.env.isEmpty ? null : helper.env,
```
to:
```dart
        environment: buildGitEnvironment(helper.env),
```

**(b)** In each of `merge`, `previewMerge`, `rebase`, `cherryPick`, and `revert`, the `Process.run(...)` calls currently look like:
```dart
    final result = await Process.run(
      _runner.executable, args,
      workingDirectory: r.path,
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    );
```
Add `environment: buildGitEnvironment(),` to all five (note `previewMerge` and `cherryPick` pass an inline arg list instead of `args` — add the same `environment:` line regardless):
```dart
    final result = await Process.run(
      _runner.executable, args,
      workingDirectory: r.path,
      environment: buildGitEnvironment(),
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    );
```

(`buildGitEnvironment` is already importable — `git_cli_write_operations.dart` already imports `git_process_runner.dart`.)

- [ ] **Step 7: Run the full suite — verify PASS**

```powershell
flutter test
```
Expected: all tests pass (the new env tests + all existing git ops tests, which still run real git correctly under `LC_ALL=C`).

- [ ] **Step 8: Commit**

```bash
git add lib/infrastructure/git/git_process_runner.dart lib/infrastructure/git/git_cli_write_operations.dart test/infrastructure/git/git_process_runner_env_test.dart
git -c commit.gpgsign=false commit -m "$(cat <<'EOF'
fix(git): force C locale so error classification is locale-independent

_classify matches English stderr substrings; on a non-English git
the auth/network/conflict categorisation broke. Force LC_ALL=C/LANG=C
on every git subprocess via a single buildGitEnvironment() helper.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Identity — license, README, About, updater

**Files:**
- Modify: `LICENSE`
- Modify: `README.md`
- Modify: `lib/ui/settings/sections/about_section.dart`
- Modify: `lib/infrastructure/updates/github_release_updater.dart`
- Test: `test/infrastructure/updates/github_release_updater_test.dart` (regression only)

- [ ] **Step 1: Add fork copyright to LICENSE (keep the original)**

In `LICENSE`, change:
```
Copyright (c) 2026 s.porta
```
to:
```
Copyright (c) 2026 s.porta
Copyright (c) 2026 zN3utr4l (fork maintainer)
```
(The MIT permission/notice text stays untouched — the original copyright is retained, satisfying the MIT condition.)

- [ ] **Step 2: Add a fork section to README**

In `README.md`, insert immediately after the `Inspired by Fork. Targets Windows and Linux.` line (line 4):

```markdown

> **Fork maintained by [zN3utr4l](https://github.com/zN3utr4l).** Based on the
> original [GitOpen](https://github.com/samuu98/GitOpen) by s.porta (MIT).
```

- [ ] **Step 3: Show the fork in the About screen**

In `lib/ui/settings/sections/about_section.dart`, after the `_Meta(label: 'License', value: 'MIT')` block (around line 60), add:

```dart
                      const SizedBox(height: 4),
                      _Meta(label: 'Fork', value: 'zN3utr4l'),
```

- [ ] **Step 4: Repoint the update checker to the fork**

In `lib/infrastructure/updates/github_release_updater.dart`, change the constructor defaults:
```dart
  GitHubReleaseUpdater({
    this.owner = 's-porta',
    this.repo = 'gitopen',
    http.Client? client,
  }) : _client = client ?? http.Client();
```
to:
```dart
  GitHubReleaseUpdater({
    this.owner = 'zN3utr4l',
    this.repo = 'GitOpen',
    http.Client? client,
  }) : _client = client ?? http.Client();
```

- [ ] **Step 5: Run the updater test — verify still PASS**

```powershell
flutter test test/infrastructure/updates/github_release_updater_test.dart
```
Expected: PASS (the test injects `owner: 'test-owner', repo: 'test-repo'` explicitly, so the default change does not affect it).

- [ ] **Step 6: Commit**

```bash
git add LICENSE README.md lib/ui/settings/sections/about_section.dart lib/infrastructure/updates/github_release_updater.dart
git -c commit.gpgsign=false commit -m "$(cat <<'EOF'
chore(identity): attribute fork to zN3utr4l, repoint updater

Add fork copyright (MIT original retained), README fork note, About
maintainer line, and point the release updater at zN3utr4l/GitOpen.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: Adopt very_good_analysis

> ⚠️ **Variable-effort task.** `very_good_analysis` on a ~15k-line codebase may surface many issues. Step 3 *sizes* the work before fixing. `dart fix --apply` handles most mechanically; the rest is fixed by category or, for genuinely noisy rules, disabled in `analysis_options.yaml` (allowed per the spec's risk mitigation).

**Files:**
- Modify: `pubspec.yaml`
- Modify: `analysis_options.yaml`
- Modify: (many) source files as flagged by the analyzer

- [ ] **Step 1: Add the dependency**

In `pubspec.yaml`, under `dev_dependencies:` (after `flutter_lints: ^6.0.0`), add:
```yaml
  very_good_analysis: ^7.0.0
```
Then:
```powershell
flutter pub get
```
(If `^7.0.0` is not resolvable for the project's Dart SDK `^3.11.5`, run `flutter pub add --dev very_good_analysis` and accept the resolved version.)

- [ ] **Step 2: Switch the lint ruleset (with generated-file excludes)**

Replace the entire contents of `analysis_options.yaml` with:
```yaml
include: package:very_good_analysis/analysis_options.yaml

analyzer:
  exclude:
    - "**/*.g.dart"
    - "**/*.freezed.dart"
  errors:
    # Generated/codegen-adjacent noise and stylistic rules we don't want to
    # block the build on. Tighten later in a dedicated hygiene slice.
    public_member_api_docs: ignore
```

- [ ] **Step 3: Size the work — run analyze and capture the count**

```powershell
flutter analyze > analyze_before.txt 2>&1
Get-Content analyze_before.txt -Tail 3
```
Record the issue count. (`analyze_before.txt` is scratch — do not commit it.)

- [ ] **Step 4: Apply mechanical fixes**

```powershell
dart fix --apply
flutter analyze > analyze_after.txt 2>&1
Get-Content analyze_after.txt -Tail 3
```
Expected: issue count drops substantially.

- [ ] **Step 5: Resolve or silence the residual, by category**

For each remaining rule, decide fix-vs-silence and apply. Common residuals and the chosen policy:
- `lines_longer_than_80_chars` → fix by wrapping, OR if pervasive add `lines_longer_than_80_chars: false` under `linter: rules:` (the codebase already uses long lines).
- `prefer_const_constructors`, `prefer_final_locals`, `directives_ordering` → fix (mostly handled by `dart fix`).
- `avoid_print` → replace with `appLog` (the project's logger) where any `print` remains.
- Any rule that is pure churn with no value for a desktop app → add to `linter: rules:` as `false` in `analysis_options.yaml` with a one-line comment.

Re-run until clean:
```powershell
flutter analyze
```
Expected: "No issues found!"

- [ ] **Step 6: Full test run — verify nothing broke**

```powershell
flutter test
```
Expected: all pass.

- [ ] **Step 7: Commit**

```bash
git add pubspec.yaml pubspec.lock analysis_options.yaml lib test
git -c commit.gpgsign=false commit -m "$(cat <<'EOF'
chore(lint): adopt very_good_analysis and fix/triage findings

Excludes generated *.g.dart. dart fix --apply for mechanical fixes;
remaining rules fixed or explicitly disabled where pure churn.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: CI green on the fork

**Files:** none (verification). `release.yml` needs no change (repo-agnostic — confirmed).

- [ ] **Step 1: Push all commits**

```bash
git push origin slice0-foundation
```

- [ ] **Step 2: Open a PR against the fork's own default branch to trigger CI**

```bash
gh pr create --repo zN3utr4l/GitOpen --base master --head slice0-foundation \
  --title "Slice 0: fork foundation" \
  --body "Fork setup, merge-diff fix, locale fix, very_good_analysis lint."
```

- [ ] **Step 3: Watch CI to green**

```bash
gh run watch --repo zN3utr4l/GitOpen
```
Expected: both `windows-latest` and `ubuntu-latest` matrix jobs pass (Analyze + Test). If CI fails on a step that passed locally, reproduce that exact step locally and fix before merging.

- [ ] **Step 4: (Optional) merge the slice**

Use the `superpowers:finishing-a-development-branch` skill to decide merge vs PR cleanup once CI is green.

---

## Self-Review

**Spec coverage** (each spec scope item → task):
- Fork & remotes & Actions → Task 0 ✓
- LICENSE + README + About + updater + release.yml → Task 3 (release.yml: confirmed no-op) ✓
- Bug 1 merge diff (vs first parent, TDD) → Task 1 ✓
- Bug 2 locale (`LC_ALL=C`, central, merge with credential env) → Task 2 ✓
- very_good_analysis lint → Task 4 ✓
- analyze clean + tests green, local & CI → Task 4 step 6 + Task 5 ✓
- TDD red-first on both bugs → Task 1 step 3, Task 2 step 2 ✓

**Placeholder scan:** No TBD/TODO. Task 4 is variable-effort by nature (unknowable lint count) but every *step* is a concrete command; the only judgement call (fix vs silence a rule) has an explicit policy. No invented symbols — `buildGitEnvironment`, `kGitLocaleEnv`, `withMergeCommit` are all defined before use.

**Type/name consistency:** `buildGitEnvironment` (Task 2 steps 3/5/6) and `withMergeCommit` (Task 1 steps 1/2) names match across all references. Git flags `--first-parent -m` verified empirically against merge/normal/root commits.
