import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitopen/application/git/git_read_operations.dart';
import 'package:gitopen/application/providers.dart';
import 'package:gitopen/domain/commits/commit_info.dart';
import 'package:gitopen/domain/commits/commit_sha.dart';
import 'package:gitopen/domain/commits/commit_signature.dart';
import 'package:gitopen/domain/diff/diff_hunk.dart';
import 'package:gitopen/domain/diff/diff_line.dart';
import 'package:gitopen/domain/diff/diff_result.dart';
import 'package:gitopen/domain/diff/diff_spec.dart';
import 'package:gitopen/domain/diff/file_diff.dart';
import 'package:gitopen/domain/refs/branch.dart';
import 'package:gitopen/domain/repositories/repo_id.dart';
import 'package:gitopen/domain/repositories/repo_location.dart';
import 'package:gitopen/ui/dialogs/compare_refs_dialog.dart';
import 'package:gitopen/ui/theme/app_palette.dart';

final CommitSha _fromSha = CommitSha('a' * 40);
final CommitSha _toSha = CommitSha('b' * 40);

CommitInfo _commit(String shaChar, String summary) {
  final sig = CommitSignature('Ada', 'a@x.io', DateTime.utc(2026, 6));
  return CommitInfo(
    sha: CommitSha(shaChar * 40),
    parentShas: const [],
    author: sig,
    committer: sig,
    summary: summary,
    message: summary,
  );
}

final class _FakeReadOps implements GitReadOperations {
  @override
  Future<({int left, int right})> countDivergence(
    RepoLocation repo,
    CommitSha a,
    CommitSha b,
  ) async => (left: 1, right: 2);

  @override
  Stream<CommitInfo> getCommits(RepoLocation repo, CommitQuery query) {
    if (query.refSpec == '${_toSha.value}..${_fromSha.value}') {
      return Stream.fromIterable([_commit('c', 'only on from')]);
    }
    return Stream.fromIterable([_commit('d', 'only on to')]);
  }

  @override
  Future<DiffResult> getDiff(
    RepoLocation repo,
    DiffSpec spec, {
    bool ignoreWhitespace = false,
  }) async {
    expect(spec, DiffSpecCommitVsCommit(_fromSha, _toSha));
    return const DiffResult(files: [
      FileDiff(
        path: 'lib/x.dart',
        changeKind: FileChangeKind.modified,
        isBinary: false,
        linesAdded: 1,
        linesDeleted: 0,
        hunks: [
          DiffHunk(
            oldStart: 1,
            oldCount: 0,
            newStart: 1,
            newCount: 1,
            header: '@@ -1,0 +1,1 @@',
            lines: [
              DiffLine(
                kind: DiffLineKind.addition,
                content: 'hello',
                newLine: 1,
              ),
            ],
          ),
        ],
      ),
    ]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

void main() {
  testWidgets('shows counts, both commit lists and the combined diff',
      (tester) async {
    final repo = RepoLocation(RepoId.newId(), 'unused', 'repo');
    final from = Branch(
      name: 'main',
      fullName: 'refs/heads/main',
      isRemote: false,
      isCurrent: true,
      ahead: 0,
      behind: 0,
      tipSha: _fromSha,
    );
    final to = Branch(
      name: 'feature',
      fullName: 'refs/heads/feature',
      isRemote: false,
      isCurrent: false,
      ahead: 0,
      behind: 0,
      tipSha: _toSha,
    );
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
                  onPressed: () => CompareRefsDialog.show(
                    context,
                    repo: repo,
                    from: from,
                    to: to,
                  ),
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

    expect(find.textContaining('main'), findsWidgets);
    expect(find.textContaining('feature'), findsWidgets);
    expect(find.text('Only on main (1)'), findsOneWidget);
    expect(find.text('Only on feature (2)'), findsOneWidget);
    expect(find.text('only on from'), findsOneWidget);
    expect(find.text('only on to'), findsOneWidget);
    expect(find.text('lib/x.dart'), findsOneWidget);
    expect(find.text('hello'), findsOneWidget);
  });
}
