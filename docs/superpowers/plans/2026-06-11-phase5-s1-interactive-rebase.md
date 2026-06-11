# Phase 5 — S1 Full Interactive Rebase Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Upgrade the existing interactive-rebase feature to full parity: `reword` action, per-commit multiline messages for reword/squash, drag-to-reorder, plan validation, and a branch-context-menu entry point.

**Architecture:** The dialog→controller→service→infra chain already exists (`InteractiveRebaseDialog`, `interactiveRebase` on controller/service/write-ops, `_scriptedRebase` in `GitCliSequencerWriter`). This slice adds: `RebaseTodoAction.reword` + an optional `message` on `RebaseTodoEntry`; pure helpers `validateRebasePlan` and `plannedEditorMessages` in application; a multi-message `GIT_EDITOR` script (numbered message files + counter) replacing the single-message `cp` trick in `_scriptedRebase`; dialog upgrades; a sidebar entry.

**Tech Stack:** Dart/Flutter, riverpod, system git CLI, real-git fixture tests (`RepoFixture.withRebaseHistory()` → `f.rebaseShas[0..3]` = c0 base, c1, c2, c3).

**Branch:** `feat/phase5-s1-interactive-rebase` (already created; spec committed). Version bump `0.1.17+18` → `0.1.18+19` in the final task.

---

## File Structure

- Modify: `lib/application/git/git_write_operations.dart` (enum + entry message)
- Create: `lib/application/git/rebase_plan.dart` (pure validation + editor-message planning)
- Create: `test/application/git/rebase_plan_test.dart`
- Modify: `lib/infrastructure/git/git_cli_sequencer_writer.dart` (multi-message `_scriptedRebase`)
- Modify: `test/infrastructure/git/git_cli_write_operations_interactive_rebase_test.dart` (reword/squash-message fixtures)
- Modify: `lib/ui/dialogs/interactive_rebase_dialog.dart` (drag reorder, reword, message editors, validation)
- Create: `test/ui/dialogs/interactive_rebase_dialog_test.dart`
- Modify: `lib/ui/sidebar/branch_tree_view.dart` (menu entry)
- Modify: `pubspec.yaml` (version)

---

### Task 1: `reword` action + entry message + pure plan helpers

**Files:**
- Modify: `lib/application/git/git_write_operations.dart:13-26`
- Create: `lib/application/git/rebase_plan.dart`
- Test: `test/application/git/rebase_plan_test.dart`

- [ ] **Step 1: Extend the value objects** in `git_write_operations.dart` — replace lines 13-26 with:

```dart
/// A single action in an interactive-rebase todo list. `edit` is
/// intentionally omitted — pausing for amend stays on the dedicated
/// edit-at-commit flow.
enum RebaseTodoAction { pick, reword, squash, fixup, drop }

/// One line of a generated interactive-rebase instruction list: apply
/// [action] to the commit [sha]. Entries are supplied to
/// [GitWriteOperations.interactiveRebase] in the desired FINAL order,
/// OLDEST-FIRST (the same order git writes its instruction sheet).
///
/// [message] applies to `reword` (the new commit message) and `squash`
/// (the combined message of its fold group). `null` keeps what git
/// proposes.
final class RebaseTodoEntry {
  const RebaseTodoEntry(this.sha, this.action, {this.message});
  final CommitSha sha;
  final RebaseTodoAction action;
  final String? message;
}
```

- [ ] **Step 2: Write the failing pure tests** at `test/application/git/rebase_plan_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:gitopen/application/git/git_write_operations.dart';
import 'package:gitopen/application/git/rebase_plan.dart';
import 'package:gitopen/domain/commits/commit_sha.dart';

RebaseTodoEntry e(String sha, RebaseTodoAction a, [String? msg]) =>
    RebaseTodoEntry(CommitSha(sha * 8), a, message: msg);

void main() {
  group('validateRebasePlan', () {
    test('null for a plain pick plan', () {
      expect(
        validateRebasePlan([
          e('a', RebaseTodoAction.pick),
          e('b', RebaseTodoAction.squash),
        ]),
        isNull,
      );
    });

    test('rejects an empty plan and an all-drop plan', () {
      expect(validateRebasePlan(const []), isNotNull);
      expect(
        validateRebasePlan([e('a', RebaseTodoAction.drop)]),
        isNotNull,
      );
    });

    test('rejects squash/fixup as the first kept commit', () {
      expect(
        validateRebasePlan([
          e('a', RebaseTodoAction.squash),
          e('b', RebaseTodoAction.pick),
        ]),
        contains('fold'),
      );
      expect(
        validateRebasePlan([
          e('a', RebaseTodoAction.drop),
          e('b', RebaseTodoAction.fixup),
        ]),
        contains('fold'),
      );
    });
  });

  group('plannedEditorMessages', () {
    test('no editor stops for pick/fixup/drop-only plans', () {
      expect(
        plannedEditorMessages([
          e('a', RebaseTodoAction.pick),
          e('b', RebaseTodoAction.fixup),
          e('c', RebaseTodoAction.drop),
        ]),
        isEmpty,
      );
    });

    test('one stop per reword, in todo order', () {
      expect(
        plannedEditorMessages([
          e('a', RebaseTodoAction.reword, 'new a'),
          e('b', RebaseTodoAction.pick),
          e('c', RebaseTodoAction.reword), // keep original
        ]),
        equals(['new a', null]),
      );
    });

    test('one stop per fold group containing a squash', () {
      expect(
        plannedEditorMessages([
          e('a', RebaseTodoAction.pick),
          e('b', RebaseTodoAction.squash, 'combined'),
          e('c', RebaseTodoAction.fixup),
          e('d', RebaseTodoAction.pick),
          e('f', RebaseTodoAction.fixup), // fixup-only group: no stop
        ]),
        equals(['combined']),
      );
    });

    test('a drop splits a fold run into two groups', () {
      expect(
        plannedEditorMessages([
          e('a', RebaseTodoAction.pick),
          e('b', RebaseTodoAction.squash, 'first'),
          e('c', RebaseTodoAction.drop),
          e('d', RebaseTodoAction.squash, 'second'),
        ]),
        equals(['first', 'second']),
      );
    });

    test('reword closes a pending fold group before its own stop', () {
      expect(
        plannedEditorMessages([
          e('a', RebaseTodoAction.pick),
          e('b', RebaseTodoAction.squash), // default combined message
          e('c', RebaseTodoAction.reword, 'r'),
        ]),
        equals([null, 'r']),
      );
    });

    test('last non-null squash message in a group wins', () {
      expect(
        plannedEditorMessages([
          e('a', RebaseTodoAction.pick),
          e('b', RebaseTodoAction.squash, 'one'),
          e('c', RebaseTodoAction.squash, 'two'),
        ]),
        equals(['two']),
      );
    });
  });
}
```

- [ ] **Step 3: Run — must fail to compile** (`rebase_plan.dart` missing, `reword` undefined)

Run: `& "C:\Users\g.chirico\flutter\bin\flutter.bat" test test/application/git/rebase_plan_test.dart`
Expected: compile error.

- [ ] **Step 4: Implement `lib/application/git/rebase_plan.dart`**

```dart
import 'package:gitopen/application/git/git_write_operations.dart';

/// Pre-flight check for an interactive-rebase plan (entries OLDEST-FIRST).
/// Returns a user-facing error, or `null` when the plan can run.
String? validateRebasePlan(List<RebaseTodoEntry> plan) {
  final kept = plan.where((p) => p.action != RebaseTodoAction.drop).toList();
  if (kept.isEmpty) return 'The plan must keep at least one commit.';
  final first = kept.first.action;
  if (first == RebaseTodoAction.squash || first == RebaseTodoAction.fixup) {
    return 'The first kept commit cannot fold (squash/fixup) — there is no '
        'previous commit to fold into.';
  }
  return null;
}

/// The ordered commit-message editor stops git will raise for [plan]
/// (entries OLDEST-FIRST). One stop per `reword`; one stop per maximal run
/// of consecutive squash/fixup commands that contains at least one
/// `squash` (git opens the editor once, at the end of the run). Any other
/// command — including `drop` — ends a run. `null` keeps the message git
/// proposes at that stop.
List<String?> plannedEditorMessages(List<RebaseTodoEntry> plan) {
  final stops = <String?>[];
  String? groupMessage;
  var groupHasSquash = false;
  var inGroup = false;

  void closeGroup() {
    if (inGroup && groupHasSquash) stops.add(groupMessage);
    inGroup = false;
    groupHasSquash = false;
    groupMessage = null;
  }

  for (final entry in plan) {
    switch (entry.action) {
      case RebaseTodoAction.squash:
        inGroup = true;
        groupHasSquash = true;
        if (entry.message != null) groupMessage = entry.message;
      case RebaseTodoAction.fixup:
        inGroup = true;
      case RebaseTodoAction.reword:
        closeGroup();
        stops.add(entry.message);
      case RebaseTodoAction.pick:
      case RebaseTodoAction.drop:
        closeGroup();
    }
  }
  closeGroup();
  return stops;
}
```

- [ ] **Step 5: Run — pure tests pass; fix fallout from the enum change**

Run: `& "C:\Users\g.chirico\flutter\bin\flutter.bat" test test/application/git/rebase_plan_test.dart`
Expected: PASS. Then `& "C:\Users\g.chirico\flutter\bin\flutter.bat" analyze` — the new `reword` case breaks exhaustive switches: `git_cli_sequencer_writer.dart` `interactiveRebase` (add `RebaseTodoAction.reword => 'reword'`) and `interactive_rebase_dialog.dart` `_actionLabel` (add `RebaseTodoAction.reword => 'reword'`). Fix those two switches only (full UI work comes in Task 3).

- [ ] **Step 6: Commit**

```powershell
git add lib/application/git/git_write_operations.dart lib/application/git/rebase_plan.dart lib/infrastructure/git/git_cli_sequencer_writer.dart lib/ui/dialogs/interactive_rebase_dialog.dart test/application/git/rebase_plan_test.dart
git commit -m "feat(phase5): reword todo action + pure rebase-plan helpers"
```

---

### Task 2: Multi-message `_scriptedRebase`

**Files:**
- Modify: `lib/infrastructure/git/git_cli_sequencer_writer.dart`
- Test: `test/infrastructure/git/git_cli_write_operations_interactive_rebase_test.dart`

- [ ] **Step 1: Write the failing real-git tests** — append inside `main()` of the interactive-rebase test file (helpers `loc`, `logSubjects`, `commitCount` already exist there):

```dart
  /// Full message (subject + body) of a commit selected by subject.
  Future<String> fullMessageOf(String path, String subject) async {
    final sha = await Process.run(
      'git',
      ['log', '--format=%H', '--grep', '^$subject\$', '-1'],
      workingDirectory: path,
    );
    final r = await Process.run(
      'git',
      ['log', '--format=%B', '-1', (sha.stdout as String).trim()],
      workingDirectory: path,
    );
    return (r.stdout as String).trim();
  }

  test('REWORD via the plan rewrites the message', () async {
    final f = await RepoFixture.withRebaseHistory();
    try {
      final sut = GitCliWriteOperations();
      final res = await sut.interactiveRebase(
        loc(f),
        CommitSha(f.rebaseShas[0]),
        [
          RebaseTodoEntry(
            CommitSha(f.rebaseShas[1]),
            RebaseTodoAction.reword,
            message: 'c1 reworded\n\nwith a body',
          ),
          RebaseTodoEntry(CommitSha(f.rebaseShas[2]), RebaseTodoAction.pick),
          RebaseTodoEntry(CommitSha(f.rebaseShas[3]), RebaseTodoAction.pick),
        ],
      );
      expect(res, isA<GitSuccess<RebaseOutcome>>());
      expect((res as GitSuccess<RebaseOutcome>).value, isA<RebaseApplied>());
      final subjects = await logSubjects(f.path);
      expect(subjects, equals(['c3', 'c2', 'c1 reworded', 'c0 base']));
      expect(
        await fullMessageOf(f.path, 'c1 reworded'),
        'c1 reworded\n\nwith a body',
      );
    } finally {
      await f.dispose();
    }
  });

  test('SQUASH with a custom message uses it for the folded commit',
      () async {
    final f = await RepoFixture.withRebaseHistory();
    try {
      final sut = GitCliWriteOperations();
      final res = await sut.interactiveRebase(
        loc(f),
        CommitSha(f.rebaseShas[0]),
        [
          RebaseTodoEntry(CommitSha(f.rebaseShas[1]), RebaseTodoAction.pick),
          RebaseTodoEntry(
            CommitSha(f.rebaseShas[2]),
            RebaseTodoAction.squash,
            message: 'c1+c2 folded',
          ),
          RebaseTodoEntry(CommitSha(f.rebaseShas[3]), RebaseTodoAction.pick),
        ],
      );
      expect(res, isA<GitSuccess<RebaseOutcome>>());
      expect((res as GitSuccess<RebaseOutcome>).value, isA<RebaseApplied>());
      expect(await logSubjects(f.path), equals(['c3', 'c1+c2 folded', 'c0 base']));
      expect(await tracks(f.path, 'c2.txt'), isTrue);
    } finally {
      await f.dispose();
    }
  });

  test('REWORD and SQUASH messages land on the right stops', () async {
    final f = await RepoFixture.withRebaseHistory();
    try {
      final sut = GitCliWriteOperations();
      final res = await sut.interactiveRebase(
        loc(f),
        CommitSha(f.rebaseShas[0]),
        [
          RebaseTodoEntry(
            CommitSha(f.rebaseShas[1]),
            RebaseTodoAction.reword,
            message: 'c1 first stop',
          ),
          RebaseTodoEntry(CommitSha(f.rebaseShas[2]), RebaseTodoAction.pick),
          RebaseTodoEntry(
            CommitSha(f.rebaseShas[3]),
            RebaseTodoAction.squash,
            message: 'c2+c3 second stop',
          ),
        ],
      );
      expect(res, isA<GitSuccess<RebaseOutcome>>());
      expect(
        await logSubjects(f.path),
        equals(['c2+c3 second stop', 'c1 first stop', 'c0 base']),
      );
    } finally {
      await f.dispose();
    }
  });
```

- [ ] **Step 2: Run — the reword/squash-message tests FAIL** (messages ignored: squash keeps the combined default, reword keeps the original via `core.editor=true`)

Run: `& "C:\Users\g.chirico\flutter\bin\flutter.bat" test test/infrastructure/git/git_cli_write_operations_interactive_rebase_test.dart`

- [ ] **Step 3: Implement multi-message support** in `git_cli_sequencer_writer.dart`:

3a. Add the import `import 'package:gitopen/application/git/rebase_plan.dart';`.

3b. `interactiveRebase` — add the `reword` verb and pass the planned stops:

```dart
  Future<GitResult<RebaseOutcome>> interactiveRebase(
    RepoLocation r,
    CommitSha onto,
    List<RebaseTodoEntry> plan,
  ) {
    final todo = StringBuffer();
    for (final e in plan) {
      final verb = switch (e.action) {
        RebaseTodoAction.pick => 'pick',
        RebaseTodoAction.reword => 'reword',
        RebaseTodoAction.squash => 'squash',
        RebaseTodoAction.fixup => 'fixup',
        RebaseTodoAction.drop => 'drop',
      };
      todo.writeln('$verb ${e.sha.value}');
    }
    return _scriptedRebase(
      r,
      onto.value,
      todo.toString(),
      editorMessages: plannedEditorMessages(plan),
    );
  }
```

3c. `rewordCommit` — change the `_scriptedRebase` call's named arg from `commitMessage: message` to `editorMessages: [message]`.

3d. `_scriptedRebase` — replace the `String? commitMessage` parameter and the single-message editor block:

```dart
  /// Runs `git rebase -i <onto>` with a fully scripted todo list (no editor
  /// prompts). [editorMessages] is the ordered list of commit-message stops
  /// the todo raises (reword lines and squash groups, see
  /// [plannedEditorMessages]); a `null` slot keeps the message git proposes
  /// at that stop.
  Future<GitResult<RebaseOutcome>> _scriptedRebase(
    RepoLocation r,
    String onto,
    String todoText, {
    List<String?> editorMessages = const [],
  }) async {
    final tmpDir = Directory.systemTemp.createTempSync('gitopen-irebase-');
    final todoFile = File(p.join(tmpDir.path, 'todo'))
      ..writeAsStringSync(todoText);
    final todoPosix = todoFile.path.replaceAll(r'\', '/');

    // Editor strategy: git invokes `sh -c "$GIT_EDITOR <msg-path>"` once per
    // message stop, in todo order. A generated script pops numbered message
    // files (msg-0, msg-1, …) driven by a counter file; a missing file keeps
    // git's proposed message (the `null` slots). With no stops at all a
    // no-op `true` editor suffices.
    var editor = 'true';
    if (editorMessages.isNotEmpty) {
      final dirPosix = tmpDir.path.replaceAll(r'\', '/');
      for (var i = 0; i < editorMessages.length; i++) {
        final message = editorMessages[i];
        if (message == null) continue;
        File(p.join(tmpDir.path, 'msg-$i')).writeAsStringSync(
          message.endsWith('\n') ? message : '$message\n',
        );
      }
      File(p.join(tmpDir.path, 'counter')).writeAsStringSync('0');
      File(p.join(tmpDir.path, 'editor.sh')).writeAsStringSync(
        '#!/bin/sh\n'
        "n=\$(cat '$dirPosix/counter')\n"
        "echo \$((n+1)) > '$dirPosix/counter'\n"
        'if [ -f "$dirPosix/msg-\$n" ]; then cp "$dirPosix/msg-\$n" "\$1"; fi\n',
      );
      editor = "sh '$dirPosix/editor.sh'";
    }
```

The rest of the method (args, env, capture, outcome mapping, cleanup) is unchanged — `'GIT_EDITOR': editor` already points at the variable.

- [ ] **Step 4: Run the infra file — all tests pass (old + new)**

Run: `& "C:\Users\g.chirico\flutter\bin\flutter.bat" test test/infrastructure/git/git_cli_write_operations_interactive_rebase_test.dart`
Also run the reword regression: `& "C:\Users\g.chirico\flutter\bin\flutter.bat" test test/infrastructure/git/git_cli_write_operations_reword_test.dart` (locate the actual file with `Glob test/infrastructure/git/*reword*` — the rewordCommit tests must keep passing through the new path).

- [ ] **Step 5: Commit**

```powershell
git add lib/infrastructure/git/git_cli_sequencer_writer.dart test/infrastructure/git/git_cli_write_operations_interactive_rebase_test.dart
git commit -m "feat(phase5): multi-stop commit messages in scripted interactive rebase"
```

---

### Task 3: Dialog — drag reorder, reword, message editors, validation

**Files:**
- Modify: `lib/ui/dialogs/interactive_rebase_dialog.dart`
- Test: `test/ui/dialogs/interactive_rebase_dialog_test.dart`

- [ ] **Step 1: Write the failing widget test** (fake read ops via `noSuchMethod`, same pattern as `test/ui/sidebar/sidebar_data_provider_test.dart`):

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitopen/application/git/git_read_operations.dart';
import 'package:gitopen/application/git/git_write_operations.dart';
import 'package:gitopen/application/providers.dart';
import 'package:gitopen/domain/commits/commit_info.dart';
import 'package:gitopen/domain/commits/commit_sha.dart';
import 'package:gitopen/domain/commits/commit_signature.dart';
import 'package:gitopen/domain/repositories/repo_id.dart';
import 'package:gitopen/domain/repositories/repo_location.dart';
import 'package:gitopen/ui/dialogs/interactive_rebase_dialog.dart';
import 'package:gitopen/ui/theme/app_palette.dart';

CommitInfo _commit(String shaChar, String summary) {
  final sig = CommitSignature('Ada', 'a@x.io', DateTime.utc(2026, 6));
  return CommitInfo(
    sha: CommitSha(shaChar * 40),
    parentShas: const [],
    author: sig,
    committer: sig,
    summary: summary,
    message: '$summary\n\nbody of $summary',
  );
}

final class _FakeReadOps implements GitReadOperations {
  // Newest-first, like `git log`.
  final commits = [_commit('b', 'second'), _commit('a', 'first')];

  @override
  Stream<CommitInfo> getCommits(RepoLocation repo, CommitQuery query) =>
      Stream.fromIterable(commits);

  @override
  Future<String?> getCommitFullMessage(RepoLocation repo, CommitSha sha) async =>
      'original message of ${sha.short()}';

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

void main() {
  late List<RebaseTodoEntry>? result;

  Future<void> pump(WidgetTester tester) async {
    result = null;
    final repo = RepoLocation(RepoId.newId(), 'unused', 'repo');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          gitReadOperationsProvider.overrideWithValue(_FakeReadOps()),
        ],
        child: MaterialApp(
          theme: ThemeData(extensions: [AppPalette.dark()]),
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () async {
                    result = await InteractiveRebaseDialog.show(
                      context,
                      repo: repo,
                      onto: CommitSha('0' * 40),
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> selectAction(
    WidgetTester tester,
    String commitSummary,
    String action,
  ) async {
    // The dropdown sits in the same row as the summary; open the one whose
    // row contains the summary text.
    final row = find.ancestor(
      of: find.text(commitSummary),
      matching: find.byType(Row),
    );
    await tester.tap(
      find.descendant(of: row.first, matching: find.text('pick')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(action).last);
    await tester.pumpAndSettle();
  }

  testWidgets('reword shows a prefilled message editor and returns it',
      (tester) async {
    await pump(tester);
    await selectAction(tester, 'second', 'reword');

    // Message field appears, prefilled with the original full message.
    final field = find.byType(TextField);
    expect(field, findsOneWidget);
    expect(
      tester.widget<TextField>(field).controller!.text,
      contains('original message'),
    );

    await tester.enterText(field, 'second, reworded');
    await tester.tap(find.text('Start rebase'));
    await tester.pumpAndSettle();

    // Returned oldest-first: [first(pick), second(reword + message)].
    expect(result, isNotNull);
    expect(result!.length, 2);
    expect(result![0].action, RebaseTodoAction.pick);
    expect(result![1].action, RebaseTodoAction.reword);
    expect(result![1].message, 'second, reworded');
  });

  testWidgets('a fold-first plan blocks Start with a validation message',
      (tester) async {
    await pump(tester);
    // 'first' is the OLDEST commit (bottom row) — folding it is invalid.
    await selectAction(tester, 'first', 'squash');

    expect(find.textContaining('cannot fold'), findsOneWidget);
    final button = find.widgetWithText(FilledButton, 'Start rebase');
    // AppButton.primary builds a FilledButton; disabled = onPressed == null.
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
  });
}
```

NOTE — if `AppButton.primary` is not `FilledButton`-based, open `lib/ui/dialogs/app_dialog.dart` (or wherever `AppButton` lives, locate with Grep) and adapt the disabled-button assertion to the actual inner widget type. Keep the assertion "onPressed is null".

- [ ] **Step 2: Run — fails** (no message editor, no validation, dropdown lacks reword wiring)

Run: `& "C:\Users\g.chirico\flutter\bin\flutter.bat" test test/ui/dialogs/interactive_rebase_dialog_test.dart`

- [ ] **Step 3: Rewrite the dialog internals.** In `interactive_rebase_dialog.dart`:

3a. `_PlanRow` gains message state:

```dart
class _PlanRow {
  _PlanRow(this.commit, this.action);
  final CommitInfo commit;
  RebaseTodoAction action;

  /// Lazily created when the action first becomes reword/squash; kept
  /// afterwards so switching away and back preserves the draft.
  TextEditingController? messageController;
  bool messageLoaded = false;

  bool get wantsMessage =>
      action == RebaseTodoAction.reword || action == RebaseTodoAction.squash;
}
```

3b. State additions in `_InteractiveRebaseDialogState`:

```dart
  @override
  void dispose() {
    for (final row in _plan ?? const <_PlanRow>[]) {
      row.messageController?.dispose();
    }
    super.dispose();
  }

  /// Reword prefills with the commit's full message (fetched once);
  /// squash starts empty (= keep git's combined message).
  Future<void> _onActionChanged(_PlanRow row, RebaseTodoAction action) async {
    setState(() => row.action = action);
    if (!row.wantsMessage || row.messageLoaded) return;
    row.messageController ??= TextEditingController();
    row.messageLoaded = true;
    if (action == RebaseTodoAction.reword) {
      final original = await ref
          .read(gitReadOperationsProvider)
          .getCommitFullMessage(widget.repo, row.commit.sha);
      if (!mounted) return;
      setState(() => row.messageController!.text = original ?? '');
    }
  }

  /// Oldest-first entries as currently configured (dialog list is
  /// newest-first). Empty message == null == keep git's proposal.
  List<RebaseTodoEntry> _entries() => [
        for (final row in _plan!.reversed)
          RebaseTodoEntry(
            row.commit.sha,
            row.action,
            message: (row.wantsMessage &&
                    (row.messageController?.text.trim().isNotEmpty ?? false))
                ? row.messageController!.text.trim()
                : null,
          ),
      ];
```

`_confirm` becomes `Navigator.pop(context, _entries());` (keep the empty-plan guard).

3c. In `build`, after `_ensurePlan(commits)`, compute the validation and replace the `ListView.separated` block and the Start button:

```dart
          _ensurePlan(commits);
          final plan = _plan!;
          final validationError = validateRebasePlan([
            for (final row in plan.reversed)
              RebaseTodoEntry(row.commit.sha, row.action),
          ]);
```

(import `package:gitopen/application/git/rebase_plan.dart`)

List — `ReorderableListView.builder` with drag handles, keeping the up/down buttons:

```dart
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 360),
                child: ReorderableListView.builder(
                  shrinkWrap: true,
                  buildDefaultDragHandles: false,
                  itemCount: plan.length,
                  onReorder: (oldIndex, newIndex) {
                    setState(() {
                      if (newIndex > oldIndex) newIndex--;
                      plan.insert(newIndex, plan.removeAt(oldIndex));
                    });
                  },
                  itemBuilder: (context, i) => _PlanRowTile(
                    key: ValueKey(plan[i].commit.sha.value),
                    index: i,
                    row: plan[i],
                    palette: palette,
                    isFirst: i == 0,
                    isLast: i == plan.length - 1,
                    onActionChanged: (a) => _onActionChanged(plan[i], a),
                    onUp: () => _move(i, -1),
                    onDown: () => _move(i, 1),
                  ),
                ),
              ),
              if (validationError != null) ...[
                const SizedBox(height: 8),
                Text(
                  validationError,
                  style: TextStyle(color: palette.accentErr, fontSize: 11.5),
                ),
              ],
```

Start button gains the validation gate:

```dart
        AppButton.primary(
          label: 'Start rebase',
          icon: Icons.playlist_play,
          onPressed: (_plan == null || _plan!.isEmpty || validationError != null)
              ? null
              : _confirm,
        ),
```

3d. `_PlanRowTile` becomes a Column: the existing Row (unchanged except a leading drag handle and the new `index` field) plus the message editor when `row.wantsMessage`:

```dart
class _PlanRowTile extends StatelessWidget {
  const _PlanRowTile({
    required this.index,
    required this.row,
    required this.palette,
    required this.isFirst,
    required this.isLast,
    required this.onActionChanged,
    required this.onUp,
    required this.onDown,
    super.key,
  });
  final int index;
  final _PlanRow row;
  final AppPalette palette;
  final bool isFirst;
  final bool isLast;
  final ValueChanged<RebaseTodoAction> onActionChanged;
  final VoidCallback onUp;
  final VoidCallback onDown;

  @override
  Widget build(BuildContext context) {
    final dropped = row.action == RebaseTodoAction.drop;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ReorderableDragStartListener(
                index: index,
                child: Icon(Icons.drag_indicator, size: 16, color: palette.fg3),
              ),
              const SizedBox(width: 6),
              // … existing dropdown / sha / summary / up / down children,
              // with the dropdown's onChanged calling onActionChanged and the
              // items built from RebaseTodoAction.values (reword included via
              // _actionLabel).
            ],
          ),
          if (row.wantsMessage)
            Padding(
              padding: const EdgeInsets.only(left: 22, top: 6),
              child: TextField(
                controller: row.messageController,
                maxLines: 4,
                minLines: 2,
                style: TextStyle(color: palette.fg0, fontSize: 12.5),
                decoration: InputDecoration(
                  isDense: true,
                  border: const OutlineInputBorder(),
                  hintText: row.action == RebaseTodoAction.squash
                      ? 'Combined message (leave empty to keep git’s)'
                      : 'New commit message',
                  hintStyle: TextStyle(color: palette.fg3, fontSize: 11.5),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
```

Also update the subtitle string to mention reword: `'Reorder, reword, squash, fixup or drop commits on top of …'`. Keep `_actionLabel` exhaustive (reword added in Task 1).

NOTE: `ReorderableListView` inside the dialog needs a bounded width — it is already inside `AppDialog(width: 600)`; if the reorderable list misbehaves under `shrinkWrap` during the widget test, wrap it in `SizedBox(height: 360)` instead of `ConstrainedBox(maxHeight:)`.

- [ ] **Step 4: Run widget test + analyze — both clean**

Run: `& "C:\Users\g.chirico\flutter\bin\flutter.bat" test test/ui/dialogs/interactive_rebase_dialog_test.dart` then `& "C:\Users\g.chirico\flutter\bin\flutter.bat" analyze`

- [ ] **Step 5: Commit**

```powershell
git add lib/ui/dialogs/interactive_rebase_dialog.dart test/ui/dialogs/interactive_rebase_dialog_test.dart
git commit -m "feat(phase5): rebase dialog - drag reorder, reword + squash messages, plan validation"
```

---

### Task 4: Branch context-menu entry point

**Files:**
- Modify: `lib/ui/sidebar/branch_tree_view.dart:78-84` (menu entries) and the `switch (selected)` block

- [ ] **Step 1: Add the menu item** right after the existing `rebase` item (inside the same `if (!isCurrent)` spread — convert the `...const [` to a non-const spread since nothing else changes):

```dart
        AppMenuItem(
          value: 'interactive_rebase',
          label: 'Interactive rebase onto this…',
          icon: Icons.playlist_play,
        ),
```

- [ ] **Step 2: Add the handler case** after `case 'rebase':` (import `package:gitopen/ui/dialogs/interactive_rebase_dialog.dart`):

```dart
      case 'interactive_rebase':
        if (!context.mounted) return;
        final plan = await InteractiveRebaseDialog.show(
          context,
          repo: widget.repo,
          onto: branch.tipSha,
        );
        if (plan == null || !context.mounted) return;
        await ref
            .read(gitActionsControllerProvider)
            .interactiveRebase(context, widget.repo, branch.tipSha, plan);
        _refresh();
```

NOTE: check `Branch.tipSha`'s nullability in `lib/domain/refs/branch.dart` first; if nullable, guard with `final tip = branch.tipSha; if (tip == null) return;` and use `tip`.

- [ ] **Step 3: analyze clean; run the sidebar widget tests**

Run: `& "C:\Users\g.chirico\flutter\bin\flutter.bat" analyze` and `& "C:\Users\g.chirico\flutter\bin\flutter.bat" test test/ui/sidebar`
Expected: clean / PASS (the menu is additive).

- [ ] **Step 4: Commit**

```powershell
git add lib/ui/sidebar/branch_tree_view.dart
git commit -m "feat(phase5): interactive rebase entry from the branch context menu"
```

---

### Task 5: Verification and PR

- [ ] **Step 1: Bump version** in `pubspec.yaml`: `0.1.17+18` → `0.1.18+19` (CI version-check needs a new unreleased version — `lib/` changed).
- [ ] **Step 2: Format touched files only** (`dart.bat format <each touched lib/test file>`) — NEVER blanket-format.
- [ ] **Step 3: Full verification**

```powershell
& "C:\Users\g.chirico\flutter\bin\flutter.bat" test -j 2
& "C:\Users\g.chirico\flutter\bin\flutter.bat" analyze
git diff --check
```

Expected: suite green (605+ tests), no issues, clean.

- [ ] **Step 4: Commit, push, PR, merge on green** (gh account: `gh auth switch --hostname github.com --user zN3utr4l`)

```powershell
git add pubspec.yaml docs/superpowers/plans/2026-06-11-phase5-s1-interactive-rebase.md
git commit -m "chore(phase5): bump version to 0.1.18"
git push -u origin feat/phase5-s1-interactive-rebase
gh pr create --title "feat(phase5): S1 - full interactive rebase" --body "<summary + spec link>"
gh pr checks --watch   # merge with --merge --delete-branch on green
```
