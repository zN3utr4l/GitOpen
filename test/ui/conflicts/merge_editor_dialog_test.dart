import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitopen/application/git/git_read_operations.dart';
import 'package:gitopen/application/git/git_result.dart';
import 'package:gitopen/application/git/git_write_operations.dart';
import 'package:gitopen/application/providers.dart';
import 'package:gitopen/domain/repositories/repo_id.dart';
import 'package:gitopen/domain/repositories/repo_location.dart';
import 'package:gitopen/ui/conflicts/merge_editor_dialog.dart';
import 'package:gitopen/ui/theme/app_palette.dart';

/// A single two-way conflict region: ours = `ours\n`, theirs = `theirs\n`.
const _conflictText = '<<<<<<< HEAD\n'
    'ours\n'
    '=======\n'
    'theirs\n'
    '>>>>>>> feature\n';

/// Read port returning canned working-tree [content] with no real I/O.
///
/// The merge editor only reads the file via `readWorkingFile`; everything else
/// is unused and routed to a throwing [noSuchMethod] so an accidental call is
/// loud rather than silent. Using a fake keeps the widget test off the `git`
/// CLI and off disk — real async never completes under the `testWidgets`
/// fake-async clock, which is what made the previous live-fixture version hang.
class _FakeRead implements GitReadOperations {
  _FakeRead(this.content);
  final String content;

  @override
  Future<String> readWorkingFile(
    RepoLocation repo,
    String relativePath,
  ) async =>
      content;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not faked');
}

/// Write port that records what the editor asked it to write/stage and reports
/// success, so the test asserts the editor's behaviour without running git.
class _FakeWrite implements GitWriteOperations {
  String? wroteContent;
  List<String>? stagedPaths;
  GitResult<void> writeResult = const GitSuccess<void>(null);
  GitResult<void> stageResult = const GitSuccess<void>(null);

  @override
  Future<GitResult<void>> writeWorkingFile(
    RepoLocation r,
    String relativePath,
    String content,
  ) async {
    wroteContent = content;
    return writeResult;
  }

  @override
  Future<GitResult<void>> stageFiles(RepoLocation r, List<String> paths) async {
    stagedPaths = List.of(paths);
    return stageResult;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not faked');
}

Widget _host(
  _FakeRead read,
  _FakeWrite write, {
  String path = 'conflict.txt',
}) {
  final repo = RepoLocation(RepoId.newId(), 'unused', 'test');
  return ProviderScope(
    overrides: [
      gitReadOperationsProvider.overrideWithValue(read),
      gitWriteOperationsProvider.overrideWithValue(write),
    ],
    child: MaterialApp(
      theme: ThemeData(extensions: [AppPalette.dark()]),
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => MergeEditorDialog.show(
                context,
                repo: repo,
                relativePath: path,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Pumps frames (bounded) until [finder] matches, instead of `pumpAndSettle`.
///
/// The dialog's transient loading state shows a [CircularProgressIndicator]
/// whose animation never quiesces, so `pumpAndSettle` would spin until the
/// test timeout. This pumps a fixed cadence until the target widget appears.
Future<void> _pumpUntil(
  WidgetTester tester,
  Finder finder, {
  int maxFrames = 60,
}) async {
  for (var i = 0; i < maxFrames; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (finder.evaluate().isNotEmpty) return;
  }
}

/// Pumps frames (bounded) until [finder] stops matching.
Future<void> _pumpUntilGone(
  WidgetTester tester,
  Finder finder, {
  int maxFrames = 60,
}) async {
  for (var i = 0; i < maxFrames; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (finder.evaluate().isEmpty) return;
  }
}

void main() {
  testWidgets('renders ours/theirs sides and choice buttons', (tester) async {
    await tester.pumpWidget(_host(_FakeRead(_conflictText), _FakeWrite()));
    await tester.tap(find.text('open'));
    await _pumpUntil(tester, find.text('Use ours'));

    expect(find.text('Resolve Conflicts'), findsOneWidget);
    expect(find.text('ours'), findsOneWidget);
    expect(find.text('theirs'), findsOneWidget);
    expect(find.text('Use ours'), findsOneWidget);
    expect(find.text('Use theirs'), findsOneWidget);
    expect(find.text('Use both'), findsOneWidget);
  });

  testWidgets('Save disabled until every conflict is chosen', (tester) async {
    await tester.pumpWidget(_host(_FakeRead(_conflictText), _FakeWrite()));
    await tester.tap(find.text('open'));
    await _pumpUntil(tester, find.text('0 of 1 conflict resolved'));

    expect(find.text('0 of 1 conflict resolved'), findsOneWidget);
    // Pick a side -> counter flips to resolved.
    await tester.tap(find.text('Use theirs'));
    await _pumpUntil(tester, find.text('1 of 1 conflict resolved'));
    expect(find.text('1 of 1 conflict resolved'), findsOneWidget);
  });

  testWidgets('saving writes the chosen side and stages the file',
      (tester) async {
    final write = _FakeWrite();
    await tester.pumpWidget(_host(_FakeRead(_conflictText), write));
    await tester.tap(find.text('open'));
    await _pumpUntil(tester, find.text('Use theirs'));

    await tester.tap(find.text('Use theirs'));
    await tester.pump();
    await tester.tap(find.text('Save resolution'));
    // Allow the async write+stage and the pop to complete.
    await _pumpUntilGone(tester, find.text('Resolve Conflicts'));

    // Dialog closed.
    expect(find.text('Resolve Conflicts'), findsNothing);

    // The editor assembled the chosen side, wrote it back, and staged the path.
    expect(write.wroteContent, 'theirs\n');
    expect(write.wroteContent, isNot(contains('<<<<<<<')));
    expect(write.stagedPaths, ['conflict.txt']);
  });

  testWidgets('offers external editor when no markers are present',
      (tester) async {
    await tester.pumpWidget(
      _host(_FakeRead('just some text\n'), _FakeWrite(), path: 'plain.txt'),
    );
    await tester.tap(find.text('open'));
    await _pumpUntil(tester, find.text('Open external editor'));

    expect(find.textContaining('No conflict markers'), findsOneWidget);
    expect(find.text('Open external editor'), findsOneWidget);
  });
}
