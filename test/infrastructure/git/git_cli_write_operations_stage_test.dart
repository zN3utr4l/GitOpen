import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitopen/application/git/git_result.dart';
import 'package:gitopen/domain/repositories/repo_id.dart';
import 'package:gitopen/domain/repositories/repo_location.dart';
import 'package:gitopen/infrastructure/git/git_cli_write_operations.dart';
import 'package:path/path.dart' as p;
import '../../_helpers/repo_fixture.dart';

void main() {
  RepoLocation loc(RepoFixture f) => RepoLocation(RepoId.newId(), f.path, 'test');

  group('stageFiles', () {
    test('stages a modified file', () async {
      final f = await RepoFixture.withLinearHistory(1);
      try {
        File(p.join(f.path, 'file_0.txt')).writeAsStringSync('changed');
        final sut = GitCliWriteOperations();
        final res = await sut.stageFiles(loc(f), ['file_0.txt']);
        expect(res, isA<GitSuccess>());
        final status = await Process.run('git', ['status', '--porcelain'], workingDirectory: f.path);
        expect(status.stdout.toString(), contains('M  file_0.txt'));
      } finally {
        await f.dispose();
      }
    });

    test('unstages a staged file', () async {
      final f = await RepoFixture.withLinearHistory(1);
      try {
        File(p.join(f.path, 'file_0.txt')).writeAsStringSync('changed');
        await Process.run('git', ['add', 'file_0.txt'], workingDirectory: f.path);
        final sut = GitCliWriteOperations();
        final res = await sut.unstageFiles(loc(f), ['file_0.txt']);
        expect(res, isA<GitSuccess>());
      } finally {
        await f.dispose();
      }
    });
  });
}
