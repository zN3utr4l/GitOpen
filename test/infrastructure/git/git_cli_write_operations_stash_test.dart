import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitopen/application/git/git_result.dart';
import 'package:gitopen/domain/repositories/repo_id.dart';
import 'package:gitopen/domain/repositories/repo_location.dart';
import 'package:gitopen/infrastructure/git/git_cli_write_operations.dart';
import 'package:path/path.dart' as p;
import '../../_helpers/repo_fixture.dart';

void main() {
  RepoLocation loc(RepoFixture f) => RepoLocation(RepoId.newId(), f.path, 't');

  test('stashSave + stashPop', () async {
    final f = await RepoFixture.withLinearHistory(1);
    try {
      File(p.join(f.path, 'file_0.txt')).writeAsStringSync('changed');
      final sut = GitCliWriteOperations();
      final saved = await sut.stashSave(loc(f), 'my stash');
      expect(saved, isA<GitSuccess<void>>());
      final list = await Process.run(
        'git',
        ['stash', 'list'],
        workingDirectory: f.path,
      );
      expect(list.stdout.toString(), contains('my stash'));
      final popped = await sut.stashPop(loc(f), 0);
      expect(popped, isA<GitSuccess<void>>());
    } finally {
      await f.dispose();
    }
  });

  test('stashSave can scope the stash to selected paths', () async {
    final f = await RepoFixture.withLinearHistory(2);
    try {
      File(p.join(f.path, 'file_0.txt')).writeAsStringSync('changed 0\n');
      File(p.join(f.path, 'file_1.txt')).writeAsStringSync('changed 1\n');

      final sut = GitCliWriteOperations();
      final saved = await sut.stashSave(
        loc(f),
        'partial',
        paths: ['file_0.txt'],
      );

      expect(saved, isA<GitSuccess<void>>());
      expect(
        File(
          p.join(f.path, 'file_0.txt'),
        ).readAsStringSync().replaceAll('\r\n', '\n'),
        'content 0\n',
      );
      expect(
        File(p.join(f.path, 'file_1.txt')).readAsStringSync(),
        'changed 1\n',
      );

      final diff = await Process.run(
        'git',
        ['stash', 'show', '--name-only', 'stash@{0}'],
        workingDirectory: f.path,
      );
      final stdout = diff.stdout.toString();
      expect(stdout, contains('file_0.txt'));
      expect(stdout, isNot(contains('file_1.txt')));
    } finally {
      await f.dispose();
    }
  });
}
