import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gitopen/application/git/git_result.dart';
import 'package:gitopen/domain/repositories/repo_id.dart';
import 'package:gitopen/domain/repositories/repo_location.dart';
import 'package:gitopen/infrastructure/git/git_cli_write_operations.dart';

import '../../_helpers/repo_fixture.dart';

void main() {
  RepoLocation loc(RepoFixture f) => RepoLocation(RepoId.newId(), f.path, 't');

  group('branch ops', () {
    test('createBranch from HEAD', () async {
      final f = await RepoFixture.withLinearHistory(1);
      try {
        final sut = GitCliWriteOperations();
        final res = await sut.createBranch(loc(f), 'feature/x');
        expect(res, isA<GitSuccess<void>>());
        final out = await Process.run(
          'git',
          ['branch', '--list'],
          workingDirectory: f.path,
        );
        expect(out.stdout.toString(), contains('feature/x'));
      } finally { await f.dispose(); }
    });

    test('checkout switches HEAD', () async {
      final f = await RepoFixture.withBranches();
      try {
        final sut = GitCliWriteOperations();
        final res = await sut.checkout(loc(f), 'feature');
        expect(res, isA<GitSuccess<void>>());
        final out = await Process.run(
          'git',
          ['rev-parse', '--abbrev-ref', 'HEAD'],
          workingDirectory: f.path,
        );
        expect(out.stdout.toString().trim(), 'feature');
      } finally { await f.dispose(); }
    });

    test('deleteBranch removes a non-current branch', () async {
      final f = await RepoFixture.withBranches();
      try {
        final sut = GitCliWriteOperations();
        await sut.checkout(loc(f), 'master');
        final res = await sut.deleteBranch(loc(f), 'feature', force: true);
        expect(res, isA<GitSuccess<void>>());
      } finally { await f.dispose(); }
    });

    test('renameBranch', () async {
      final f = await RepoFixture.withBranches();
      try {
        final sut = GitCliWriteOperations();
        final res = await sut.renameBranch(
          loc(f),
          'feature',
          'feature-renamed',
        );
        expect(res, isA<GitSuccess<void>>());
      } finally { await f.dispose(); }
    });
  });
}
