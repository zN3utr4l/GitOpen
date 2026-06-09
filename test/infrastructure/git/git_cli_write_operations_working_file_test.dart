import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gitopen/application/git/git_result.dart';
import 'package:gitopen/domain/repositories/repo_id.dart';
import 'package:gitopen/domain/repositories/repo_location.dart';
import 'package:gitopen/infrastructure/git/git_cli_read_operations.dart';
import 'package:gitopen/infrastructure/git/git_cli_write_operations.dart';
import 'package:path/path.dart' as p;

import '../../_helpers/repo_fixture.dart';

void main() {
  RepoLocation loc(RepoFixture f) =>
      RepoLocation(RepoId.newId(), f.path, 'test');

  group('writeWorkingFile', () {
    test('overwrites an existing file with the given content', () async {
      final f = await RepoFixture.withLinearHistory(1);
      try {
        const resolved = 'resolved content\n';
        final sut = GitCliWriteOperations();
        final res =
            await sut.writeWorkingFile(loc(f), 'file_0.txt', resolved);
        expect(res, isA<GitSuccess<void>>());
        expect(
          File(p.join(f.path, 'file_0.txt')).readAsStringSync(),
          resolved,
        );
      } finally {
        await f.dispose();
      }
    });

    test('creates the file when it does not yet exist', () async {
      final f = await RepoFixture.withLinearHistory(1);
      try {
        final sut = GitCliWriteOperations();
        final res = await sut.writeWorkingFile(loc(f), 'new.txt', 'hello\n');
        expect(res, isA<GitSuccess<void>>());
        expect(File(p.join(f.path, 'new.txt')).existsSync(), isTrue);
      } finally {
        await f.dispose();
      }
    });

    test('round-trips through readWorkingFile (CRLF preserved)', () async {
      final f = await RepoFixture.withLinearHistory(1);
      try {
        const body = 'one\r\ntwo\r\nthree';
        final write = GitCliWriteOperations();
        await write.writeWorkingFile(loc(f), 'rt.txt', body);
        final read =
            await GitCliReadOperations().readWorkingFile(loc(f), 'rt.txt');
        expect(read, body);
      } finally {
        await f.dispose();
      }
    });

    test('resolved file can be staged after writing', () async {
      // End-to-end: craft a conflicting merge, resolve a file in memory, write
      // it back, then `git add` it — the working-tree state must clear the
      // unmerged flag for that path.
      final f = await RepoFixture.empty();
      try {
        final file = File(p.join(f.path, 'conflict.txt'));
        await file.writeAsString('base\n');
        await _git(f.path, ['add', 'conflict.txt']);
        await _git(f.path, ['commit', '-q', '-m', 'base']);

        await _git(f.path, ['checkout', '-q', '-b', 'feature']);
        await file.writeAsString('theirs\n');
        await _git(f.path, ['add', 'conflict.txt']);
        await _git(f.path, ['commit', '-q', '-m', 'feature change']);

        await _git(f.path, ['checkout', '-q', 'master']);
        await file.writeAsString('ours\n');
        await _git(f.path, ['add', 'conflict.txt']);
        await _git(f.path, ['commit', '-q', '-m', 'master change']);

        // Trigger the conflict (merge exits non-zero — that's expected).
        await Process.run('git', ['merge', 'feature'],
            workingDirectory: f.path);

        final loc0 = loc(f);
        final write = GitCliWriteOperations();
        await write.writeWorkingFile(loc0, 'conflict.txt', 'resolved\n');
        final staged = await write.stageFiles(loc0, ['conflict.txt']);
        expect(staged, isA<GitSuccess<void>>());

        final status = await Process.run(
          'git',
          ['status', '--porcelain'],
          workingDirectory: f.path,
        );
        // After resolving + staging, the path should no longer be unmerged
        // (no 'UU'); it should be a normal staged modification ('M ').
        expect(status.stdout.toString(), isNot(contains('UU conflict.txt')));
        expect(status.stdout.toString(), contains('M  conflict.txt'));
      } finally {
        await f.dispose();
      }
    });
  });
}

Future<void> _git(String cwd, List<String> args) async {
  await Process.run('git', args, workingDirectory: cwd);
}
