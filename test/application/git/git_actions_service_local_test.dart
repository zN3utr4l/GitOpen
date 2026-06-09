import 'package:flutter_test/flutter_test.dart';
import 'package:gitopen/application/git/git_actions_service.dart';
import 'package:gitopen/application/git/git_result.dart';
import 'package:gitopen/application/git/git_write_operations.dart';
import 'package:gitopen/application/git/merge_outcome.dart';
import 'package:gitopen/domain/commits/commit_sha.dart';
import 'package:gitopen/domain/repositories/repo_id.dart';
import 'package:gitopen/domain/repositories/repo_location.dart';

/// Fake write op for the local (non-streaming) actions: returns canned
/// GitResults so the mapping to [ActionResult] can be asserted without git.
class _FakeWrite implements GitWriteOperations {
  GitResult<MergeOutcome> mergeResult =
      const GitSuccess<MergeOutcome>(MergeUpToDate());
  GitResult<CherryPickOutcome> cherryResult =
      const GitSuccess<CherryPickOutcome>(CherryPickConflict(['x.txt']));
  GitResult<void> resetResult = const GitSuccess<void>(null);

  @override
  Future<GitResult<MergeOutcome>> merge(
    RepoLocation r,
    String ref, {
    MergeStrategy strategy = MergeStrategy.defaultStrategy,
  }) async =>
      mergeResult;

  @override
  Future<GitResult<CherryPickOutcome>> cherryPick(
    RepoLocation r,
    CommitSha sha,
  ) async =>
      cherryResult;

  @override
  Future<GitResult<void>> reset(
    RepoLocation r,
    CommitSha to,
    ResetMode mode,
  ) async =>
      resetResult;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not faked');
}

void main() {
  final repo = RepoLocation(RepoId.newId(), 'unused', 'test');
  final sha = CommitSha('abcdef1');
  const strategy = MergeStrategy.defaultStrategy;

  GitActionsService service(_FakeWrite write) => GitActionsService(
        write: write,
        resolveProfile: (_) async => null,
        errorText: (e) => e.toString(),
      );

  test('merge success → success, invalidates reads+repoState, no message',
      () async {
    final write = _FakeWrite()
      ..mergeResult = const GitSuccess<MergeOutcome>(MergeUpToDate());
    final r = await service(write).merge(repo, 'feature', strategy);
    expect(r.outcome, ActionOutcome.success);
    expect(
      r.invalidate,
      unorderedEquals({RepoDataScope.reads, RepoDataScope.repoState}),
    );
    expect(r.message, isNull);
  });

  test('merge conflict → conflict outcome + count message', () async {
    final write = _FakeWrite()
      ..mergeResult =
          const GitSuccess<MergeOutcome>(MergeConflict(['a.txt', 'b.txt']));
    final r = await service(write).merge(repo, 'feature', strategy);
    expect(r.outcome, ActionOutcome.conflict);
    expect(r.message, contains('2 file(s)'));
    expect(r.invalidate, contains(RepoDataScope.repoState));
  });

  test('merge failure → failed + "Merge failed:" message', () async {
    final write = _FakeWrite()
      ..mergeResult =
          const GitFailure<MergeOutcome>(GitErrorKind.conflict, 'boom', 'boom');
    final r = await service(write).merge(repo, 'feature', strategy);
    expect(r.outcome, ActionOutcome.failed);
    expect(r.message, contains('Merge failed'));
  });

  test('cherryPick conflict → conflict + labelled message', () async {
    final write = _FakeWrite()
      ..cherryResult =
          const GitSuccess<CherryPickOutcome>(CherryPickConflict(['c.txt']));
    final r = await service(write).cherryPick(repo, sha);
    expect(r.outcome, ActionOutcome.conflict);
    expect(r.message, contains('Cherry-pick conflict'));
  });

  test('reset success → success', () async {
    final write = _FakeWrite()..resetResult = const GitSuccess<void>(null);
    final r = await service(write).reset(repo, sha, ResetMode.hard);
    expect(r.outcome, ActionOutcome.success);
  });

  test('reset failure → failed + "Reset failed:" message', () async {
    final write = _FakeWrite()
      ..resetResult =
          const GitFailure<void>(GitErrorKind.other, 'nope', 'nope');
    final r = await service(write).reset(repo, sha, ResetMode.hard);
    expect(r.outcome, ActionOutcome.failed);
    expect(r.message, contains('Reset failed'));
  });
}
