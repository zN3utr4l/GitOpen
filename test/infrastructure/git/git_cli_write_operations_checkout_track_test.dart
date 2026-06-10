import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gitopen/application/git/git_result.dart';
import 'package:gitopen/domain/repositories/repo_id.dart';
import 'package:gitopen/domain/repositories/repo_location.dart';
import 'package:gitopen/infrastructure/git/git_cli_write_operations.dart';

import '../../_helpers/repo_fixture.dart';

void main() {
  RepoLocation loc(RepoFixture f) => RepoLocation(RepoId.newId(), f.path, 't');

  /// Local repo (own master commit) with a file remote that has master +
  /// feature, already fetched so refs/remotes/origin/* exist.
  Future<(RepoFixture, RepoFixture)> fixture() async {
    final origin = await RepoFixture.withBranches();
    final local = await RepoFixture.withLinearHistory(1);
    Future<void> git(List<String> args) async {
      final r = await Process.run('git', args, workingDirectory: local.path);
      expect(r.exitCode, 0, reason: r.stderr.toString());
    }

    await git(['remote', 'add', 'origin', origin.path]);
    await git(['fetch', 'origin']);
    return (local, origin);
  }

  group('checkoutTrack', () {
    test('creates and checks out a local tracking branch', () async {
      final (local, origin) = await fixture();
      try {
        final sut = GitCliWriteOperations();
        final res = await sut.checkoutTrack(loc(local), 'origin/feature');
        expect(res, isA<GitSuccess<void>>());

        final head = await Process.run(
          'git',
          ['rev-parse', '--abbrev-ref', 'HEAD'],
          workingDirectory: local.path,
        );
        expect(head.stdout.toString().trim(), 'feature');

        final upstream = await Process.run(
          'git',
          ['rev-parse', '--abbrev-ref', 'feature@{upstream}'],
          workingDirectory: local.path,
        );
        expect(upstream.stdout.toString().trim(), 'origin/feature');
      } finally {
        await local.dispose();
        await origin.dispose();
      }
    });

    test('fails cleanly when the local branch already exists', () async {
      final (local, origin) = await fixture();
      try {
        final sut = GitCliWriteOperations();
        // local already has its own 'master' (withLinearHistory commits there).
        final res = await sut.checkoutTrack(loc(local), 'origin/master');
        expect(res, isA<GitFailure<void>>());
      } finally {
        await local.dispose();
        await origin.dispose();
      }
    });
  });
}
