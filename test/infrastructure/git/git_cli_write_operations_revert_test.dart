import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitopen/application/git/git_result.dart';
import 'package:gitopen/application/git/merge_outcome.dart';
import 'package:gitopen/domain/commits/commit_sha.dart';
import 'package:gitopen/domain/repositories/repo_id.dart';
import 'package:gitopen/domain/repositories/repo_location.dart';
import 'package:gitopen/infrastructure/git/git_cli_write_operations.dart';
import '../../_helpers/repo_fixture.dart';

void main() {
  test('revert undoes a commit', () async {
    final f = await RepoFixture.withLinearHistory(2);
    try {
      final headSha = f.headSha;
      final sut = GitCliWriteOperations();
      final res = await sut.revert(
        RepoLocation(RepoId.newId(), f.path, 't'),
        CommitSha(headSha),
      );
      expect(res, isA<GitSuccess<RevertOutcome>>());
      expect((res as GitSuccess<RevertOutcome>).value, isA<RevertApplied>());
      // Verify the revert commit appears in the log
      final out = await Process.run(
        'git',
        ['log', '--oneline'],
        workingDirectory: f.path,
      );
      expect(out.stdout.toString(), contains('Revert'));
    } finally {
      await f.dispose();
    }
  });
}
