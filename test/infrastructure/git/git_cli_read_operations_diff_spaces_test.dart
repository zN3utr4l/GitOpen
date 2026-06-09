import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gitopen/domain/diff/diff_spec.dart';
import 'package:gitopen/domain/diff/file_diff.dart';
import 'package:gitopen/domain/repositories/repo_id.dart';
import 'package:gitopen/domain/repositories/repo_location.dart';
import 'package:gitopen/infrastructure/git/git_cli_read_operations.dart';
import 'package:path/path.dart' as p;

import '../../_helpers/repo_fixture.dart';

RepoLocation loc(RepoFixture f) => RepoLocation(const RepoId('t'), f.path, 't');

void main() {
  group('GitCliReadOperations.getDiff paths with spaces', () {
    test('modified file with spaces keeps its full path and hunks', () async {
      final f = await RepoFixture.empty();
      try {
        final file = File(p.join(f.path, 'has space.txt'));
        await file.writeAsString('one\n');
        await Process.run('git', ['add', '.'], workingDirectory: f.path);
        await Process.run(
          'git',
          ['commit', '-q', '-m', 'add'],
          workingDirectory: f.path,
        );
        await file.writeAsString('one\ntwo\n');

        final sut = GitCliReadOperations();
        final diff =
            await sut.getDiff(loc(f), const DiffSpecWorkingTreeVsIndex());

        expect(diff.files, hasLength(1));
        final fd = diff.files.single;
        expect(fd.path, 'has space.txt');
        expect(fd.changeKind, FileChangeKind.modified);
        expect(fd.linesAdded, 1);
        expect(fd.hunks, isNotEmpty);
      } finally {
        await f.dispose();
      }
    });

    test('non-ascii path is not C-quote-escaped away', () async {
      final f = await RepoFixture.empty();
      try {
        final file = File(p.join(f.path, 'cafè.txt'));
        await file.writeAsString('one\n');
        await Process.run('git', ['add', '.'], workingDirectory: f.path);
        await Process.run(
          'git',
          ['commit', '-q', '-m', 'add'],
          workingDirectory: f.path,
        );
        await file.writeAsString('one\ntwo\n');

        final sut = GitCliReadOperations();
        final diff =
            await sut.getDiff(loc(f), const DiffSpecWorkingTreeVsIndex());

        // With git's default core.quotepath=true the header becomes
        // `diff --git "a/caf\303\250.txt" ...`, which the parser's
        // unquoted-path regex skips entirely — the file silently vanishes
        // from the diff view.
        expect(diff.files, hasLength(1));
        expect(diff.files.single.path, 'cafè.txt');
        expect(diff.files.single.hunks, isNotEmpty);
      } finally {
        await f.dispose();
      }
    });

    test('rename with spaces resolves old and new paths', () async {
      final f = await RepoFixture.empty();
      try {
        await File(p.join(f.path, 'old name.txt'))
            .writeAsString('stable content\nmore lines\nthird\n');
        await Process.run('git', ['add', '.'], workingDirectory: f.path);
        await Process.run(
          'git',
          ['commit', '-q', '-m', 'add'],
          workingDirectory: f.path,
        );
        await Process.run(
          'git',
          ['mv', 'old name.txt', 'new name.txt'],
          workingDirectory: f.path,
        );

        final sut = GitCliReadOperations();
        final diff = await sut.getDiff(loc(f), const DiffSpecIndexVsHead());

        expect(diff.files, hasLength(1));
        final fd = diff.files.single;
        expect(fd.changeKind, FileChangeKind.renamed);
        expect(fd.path, 'new name.txt');
        expect(fd.oldPath, 'old name.txt');
      } finally {
        await f.dispose();
      }
    });
  });
}
