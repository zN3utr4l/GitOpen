import '../../application/git/git_read_operations.dart';
import '../../domain/commits/commit_info.dart';
import '../../domain/commits/commit_sha.dart';
import '../../domain/diff/diff_result.dart';
import '../../domain/diff/diff_spec.dart';
import '../../domain/files/file_tree_entry.dart';
import '../../domain/refs/branch.dart';
import '../../domain/refs/remote.dart';
import '../../domain/refs/stash.dart';
import '../../domain/refs/tag.dart';
import '../../domain/repositories/repo_location.dart';
import '../../domain/status/repo_status.dart';
import 'git_process_runner.dart';

final class GitCliReadOperations implements GitReadOperations {
  // ignore: unused_field  — will be used in C3..C7 when methods are implemented
  final GitProcessRunner _runner;
  GitCliReadOperations({GitProcessRunner? runner})
      : _runner = runner ?? GitProcessRunner();

  @override
  Future<RepoStatus> getStatus(RepoLocation repo) =>
      throw UnimplementedError();

  @override
  Stream<CommitInfo> getCommits(RepoLocation repo, CommitQuery query) =>
      throw UnimplementedError();

  @override
  Future<List<Branch>> getBranches(RepoLocation repo) =>
      throw UnimplementedError();

  @override
  Future<List<Tag>> getTags(RepoLocation repo) =>
      throw UnimplementedError();

  @override
  Future<List<Remote>> getRemotes(RepoLocation repo) =>
      throw UnimplementedError();

  @override
  Future<List<Stash>> getStashes(RepoLocation repo) =>
      throw UnimplementedError();

  @override
  Future<DiffResult> getDiff(RepoLocation repo, DiffSpec spec) =>
      throw UnimplementedError();

  @override
  Future<List<FileTreeEntry>> getFileTree(
          RepoLocation repo, CommitSha sha, String path) =>
      throw UnimplementedError();
}
