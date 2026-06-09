import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gitopen/domain/repositories/repo_id.dart';
import 'package:gitopen/domain/repositories/repo_location.dart';
import 'package:gitopen/infrastructure/git/git_cli_read_operations.dart';
import 'package:path/path.dart' as p;

import '../../_helpers/repo_fixture.dart';

void main() {
  RepoLocation loc(RepoFixture f) =>
      RepoLocation(RepoId.newId(), f.path, 'test');

  group('readWorkingFile', () {
    test('reads back the exact bytes written to a working-tree file', () async {
      final f = await RepoFixture.withLinearHistory(1);
      try {
        const body = 'line one\nline two\n';
        File(p.join(f.path, 'note.txt')).writeAsStringSync(body);
        final sut = GitCliReadOperations();
        final read = await sut.readWorkingFile(loc(f), 'note.txt');
        expect(read, body);
      } finally {
        await f.dispose();
      }
    });

    test('preserves conflict markers verbatim', () async {
      final f = await RepoFixture.withLinearHistory(1);
      try {
        const conflicted = 'a\n'
            '<<<<<<< HEAD\n'
            'ours\n'
            '=======\n'
            'theirs\n'
            '>>>>>>> feature\n'
            'z\n';
        File(p.join(f.path, 'c.txt')).writeAsStringSync(conflicted);
        final sut = GitCliReadOperations();
        final read = await sut.readWorkingFile(loc(f), 'c.txt');
        expect(read, conflicted);
      } finally {
        await f.dispose();
      }
    });

    test('preserves CRLF line endings', () async {
      final f = await RepoFixture.withLinearHistory(1);
      try {
        const body = 'one\r\ntwo\r\n';
        File(p.join(f.path, 'crlf.txt')).writeAsStringSync(body);
        final sut = GitCliReadOperations();
        final read = await sut.readWorkingFile(loc(f), 'crlf.txt');
        expect(read, body);
      } finally {
        await f.dispose();
      }
    });
  });
}
