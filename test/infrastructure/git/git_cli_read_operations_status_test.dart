import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitopen/domain/repositories/repo_id.dart';
import 'package:gitopen/domain/repositories/repo_location.dart';
import 'package:gitopen/domain/status/working_file_entry.dart';
import 'package:gitopen/infrastructure/git/git_cli_read_operations.dart';
import 'package:path/path.dart' as p;
import '../../_helpers/repo_fixture.dart';

void main() {
  RepoLocation loc(RepoFixture f) =>
      RepoLocation(RepoId.newId(), f.path, 'test');

  group('GitCliReadOperations.getStatus', () {
    test('clean after commit', () async {
      final f = await RepoFixture.withLinearHistory(1);
      try {
        final sut = GitCliReadOperations();
        final status = await sut.getStatus(loc(f));
        expect(status.entries, isEmpty);
        expect(status.headSha?.value, f.headSha);
        expect(status.isBare, isFalse);
        expect(status.isDetached, isFalse);
        expect(status.currentBranch, 'master');
      } finally {
        await f.dispose();
      }
    });

    test('reports untracked file', () async {
      final f = await RepoFixture.withLinearHistory(1);
      File(p.join(f.path, 'new.txt')).writeAsStringSync('hi');
      try {
        final sut = GitCliReadOperations();
        final status = await sut.getStatus(loc(f));
        expect(
          status.entries.any((e) =>
              e.path == 'new.txt' &&
              e.workingTreeState == WorkingFileState.untracked),
          isTrue,
        );
      } finally {
        await f.dispose();
      }
    });

    test('reports modified file', () async {
      final f = await RepoFixture.withLinearHistory(1);
      File(p.join(f.path, 'file_0.txt')).writeAsStringSync('changed');
      try {
        final sut = GitCliReadOperations();
        final status = await sut.getStatus(loc(f));
        expect(
          status.entries.any((e) =>
              e.path == 'file_0.txt' &&
              e.workingTreeState == WorkingFileState.modified),
          isTrue,
        );
      } finally {
        await f.dispose();
      }
    });
  });
}
