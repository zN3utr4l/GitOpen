import '../../application/git/auth_spec.dart';
import '../../application/git/commit_request.dart';
import '../../application/git/git_progress.dart';
import '../../application/git/git_result.dart';
import '../../application/git/git_write_operations.dart';
import '../../application/git/merge_outcome.dart';
import '../../domain/commits/commit_sha.dart';
import '../../domain/repositories/repo_location.dart';
import 'git_process_runner.dart';

final class GitCliWriteOperations implements GitWriteOperations {
  // ignore: unused_field
  final GitProcessRunner _runner;
  GitCliWriteOperations({GitProcessRunner? runner})
      : _runner = runner ?? GitProcessRunner();

  @override
  Future<GitResult<void>> stageFiles(RepoLocation r, List<String> paths) async {
    if (paths.isEmpty) return const GitSuccess(null);
    try {
      await _runner.run(r.path, ['add', '--', ...paths]);
      return const GitSuccess(null);
    } on GitProcessException catch (e) {
      return GitFailure(_classify(e), e.stderr, e.stderr);
    }
  }

  @override
  Future<GitResult<void>> unstageFiles(RepoLocation r, List<String> paths) async {
    if (paths.isEmpty) return const GitSuccess(null);
    try {
      await _runner.run(r.path, ['restore', '--staged', '--', ...paths]);
      return const GitSuccess(null);
    } on GitProcessException catch (e) {
      return GitFailure(_classify(e), e.stderr, e.stderr);
    }
  }

  GitErrorKind _classify(GitProcessException e) {
    final s = e.stderr.toLowerCase();
    if (s.contains('auth') || s.contains('401') || s.contains('permission denied')) return GitErrorKind.auth;
    if (s.contains('network') || s.contains('could not resolve') || s.contains('connection')) return GitErrorKind.network;
    if (s.contains('non-fast-forward') || s.contains('rejected')) return GitErrorKind.nonFastForward;
    if (s.contains('conflict')) return GitErrorKind.conflict;
    if (s.contains('would be overwritten')) return GitErrorKind.dirtyWorkingTree;
    if (s.contains('unknown revision') || s.contains('not a valid ref')) return GitErrorKind.unknownRef;
    return GitErrorKind.other;
  }
  @override
  Future<GitResult<void>> stagePatch(RepoLocation r, String unifiedDiff) => throw UnimplementedError();
  @override
  Future<GitResult<void>> unstagePatch(RepoLocation r, String unifiedDiff) => throw UnimplementedError();
  @override
  Future<GitResult<void>> discardChanges(RepoLocation r, List<String> paths) => throw UnimplementedError();
  @override
  Future<GitResult<CommitSha>> commit(RepoLocation r, CommitRequest req) => throw UnimplementedError();
  @override
  Future<GitResult<void>> createBranch(RepoLocation r, String name, {CommitSha? at, bool checkout = false}) => throw UnimplementedError();
  @override
  Future<GitResult<void>> checkout(RepoLocation r, String ref, {bool force = false}) => throw UnimplementedError();
  @override
  Future<GitResult<void>> deleteBranch(RepoLocation r, String name, {bool force = false, bool remote = false}) => throw UnimplementedError();
  @override
  Future<GitResult<void>> renameBranch(RepoLocation r, String oldName, String newName) => throw UnimplementedError();
  @override
  Future<GitResult<void>> setUpstream(RepoLocation r, String branch, String upstream) => throw UnimplementedError();
  @override
  Future<GitResult<void>> createTag(RepoLocation r, String name, {CommitSha? at, String? message}) => throw UnimplementedError();
  @override
  Future<GitResult<void>> deleteTag(RepoLocation r, String name) => throw UnimplementedError();
  @override
  Stream<GitProgress> fetch(RepoLocation r, {String? remote, bool all = false, AuthSpec? auth}) => throw UnimplementedError();
  @override
  Stream<GitProgress> pull(RepoLocation r, PullStrategy strategy, {AuthSpec? auth}) => throw UnimplementedError();
  @override
  Stream<GitProgress> push(RepoLocation r, {String? remote, String? branch, bool forceWithLease = false, bool pushTags = false, AuthSpec? auth}) => throw UnimplementedError();
  @override
  Future<GitResult<void>> stashSave(RepoLocation r, String message, {bool includeUntracked = false}) => throw UnimplementedError();
  @override
  Future<GitResult<void>> stashPop(RepoLocation r, int index) => throw UnimplementedError();
  @override
  Future<GitResult<void>> stashApply(RepoLocation r, int index) => throw UnimplementedError();
  @override
  Future<GitResult<void>> stashDrop(RepoLocation r, int index) => throw UnimplementedError();
  @override
  Future<GitResult<MergeOutcome>> merge(RepoLocation r, String ref, {bool ffOnly = false, bool noCommit = false}) => throw UnimplementedError();
  @override
  Future<GitResult<void>> mergeAbort(RepoLocation r) => throw UnimplementedError();
  @override
  Future<GitResult<CommitSha>> mergeContinue(RepoLocation r) => throw UnimplementedError();
  @override
  Future<GitResult<CherryPickOutcome>> cherryPick(RepoLocation r, CommitSha sha) => throw UnimplementedError();
  @override
  Future<GitResult<void>> cherryPickAbort(RepoLocation r) => throw UnimplementedError();
  @override
  Future<GitResult<CommitSha>> cherryPickContinue(RepoLocation r) => throw UnimplementedError();
  @override
  Future<GitResult<void>> reset(RepoLocation r, CommitSha to, ResetMode mode) => throw UnimplementedError();
  @override
  Stream<GitProgress> clone(String url, String destination, {AuthSpec? auth}) => throw UnimplementedError();
}
