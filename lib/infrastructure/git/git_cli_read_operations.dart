import '../../application/git/git_read_operations.dart';
import '../../domain/commits/commit_info.dart';
import '../../domain/commits/commit_sha.dart';
import '../../domain/commits/commit_signature.dart';
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
  final GitProcessRunner _runner;
  GitCliReadOperations({GitProcessRunner? runner})
      : _runner = runner ?? GitProcessRunner();

  @override
  Future<RepoStatus> getStatus(RepoLocation repo) =>
      throw UnimplementedError();

  @override
  Stream<CommitInfo> getCommits(RepoLocation repo, CommitQuery query) async* {
    final args = <String>[
      'log', '-z',
      '--topo-order', '--date-order',
      '--format=%H%x00%P%x00%an%x00%ae%x00%aI%x00%cn%x00%ce%x00%cI%x00%s%x00%b',
    ];
    if (query.skip != null) args.add('--skip=${query.skip}');
    if (query.take != null) args.add('--max-count=${query.take}');
    if (query.refSpec != null) args.add(query.refSpec!);

    String stdout;
    try {
      stdout = await _runner.run(repo.path, args);
    } on GitProcessException catch (e) {
      // Empty repo: 'fatal: your current branch ... does not have any commits yet'
      // or 'unknown revision'. Treat both as empty.
      if (e.stderr.contains('does not have any commits yet') ||
          e.stderr.contains('bad default revision') ||
          e.stderr.contains('unknown revision')) {
        return;
      }
      rethrow;
    }

    // Each commit produces exactly 10 NUL-separated fields. The -z flag adds
    // one extra NUL terminator after each commit record, which in practice
    // means a single trailing empty string after the last commit's body.
    // Strip only that single trailing empty to avoid eating an empty body field.
    final fields = stdout.split('\x00');
    if (fields.isNotEmpty && fields.last.isEmpty) {
      fields.removeLast();
    }
    for (var i = 0; i + 9 < fields.length; i += 10) {
      yield CommitInfo(
        sha: CommitSha(fields[i]),
        parentShas: fields[i + 1].isEmpty
            ? const []
            : fields[i + 1].split(' ').map(CommitSha.new).toList(),
        author: CommitSignature(
          fields[i + 2],
          fields[i + 3],
          DateTime.parse(fields[i + 4]),
        ),
        committer: CommitSignature(
          fields[i + 5],
          fields[i + 6],
          DateTime.parse(fields[i + 7]),
        ),
        summary: fields[i + 8],
        message: fields[i + 9].isEmpty
            ? fields[i + 8]
            : '${fields[i + 8]}\n\n${fields[i + 9]}',
      );
    }
  }

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
