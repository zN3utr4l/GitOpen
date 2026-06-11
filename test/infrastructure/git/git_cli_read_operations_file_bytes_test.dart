import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gitopen/domain/commits/commit_sha.dart';
import 'package:gitopen/domain/files/file_revision.dart';
import 'package:gitopen/domain/repositories/repo_id.dart';
import 'package:gitopen/domain/repositories/repo_location.dart';
import 'package:gitopen/infrastructure/git/git_cli_read_operations.dart';
import 'package:path/path.dart' as p;

import '../../_helpers/repo_fixture.dart';

void main() {
  RepoLocation loc(RepoFixture f) => RepoLocation(RepoId.newId(), f.path, 'fx');

  Future<String> git(RepoFixture f, List<String> args) async {
    final r = await Process.run('git', args, workingDirectory: f.path);
    expect(r.exitCode, 0, reason: r.stderr.toString());
    return r.stdout.toString();
  }

  test('reads committed, parent, index and working-tree bytes', () async {
    final f = await RepoFixture.empty();
    try {
      final file = File(p.join(f.path, 'img.bin'));
      // v1 committed, then v2 committed, then v3 staged, then v4 on disk.
      await file.writeAsBytes([1, 0, 255]);
      await git(f, ['add', 'img.bin']);
      await git(f, ['commit', '-q', '-m', 'v1']);
      await file.writeAsBytes([2, 0, 254]);
      await git(f, ['add', 'img.bin']);
      await git(f, ['commit', '-q', '-m', 'v2']);
      final head = CommitSha((await git(f, ['rev-parse', 'HEAD'])).trim());
      await file.writeAsBytes([3, 0, 253]);
      await git(f, ['add', 'img.bin']);
      await file.writeAsBytes([4, 0, 252, 9]);

      final sut = GitCliReadOperations();
      final repo = loc(f);

      final atHead =
          await sut.getFileBytes(repo, FileRevisionAtCommit(head), 'img.bin');
      expect(atHead.exists, isTrue);
      expect(atHead.bytes, [2, 0, 254]);
      expect(atHead.sizeBytes, 3);

      final parent = await sut.getFileBytes(
          repo, FileRevisionParentOfCommit(head), 'img.bin');
      expect(parent.bytes, [1, 0, 255]);

      final index = await sut.getFileBytes(
          repo, const FileRevisionIndex(), 'img.bin');
      expect(index.bytes, [3, 0, 253]);

      final headRev = await sut.getFileBytes(
          repo, const FileRevisionHead(), 'img.bin');
      expect(headRev.bytes, [2, 0, 254]);

      final worktree = await sut.getFileBytes(
          repo, const FileRevisionWorkingTree(), 'img.bin');
      expect(worktree.bytes, [4, 0, 252, 9]);
      expect(worktree.sizeBytes, 4);
    } finally {
      await f.dispose();
    }
  });

  test('missing paths and a root commit parent report missing', () async {
    final f = await RepoFixture.withLinearHistory(1);
    try {
      final sut = GitCliReadOperations();
      final repo = loc(f);
      final root = CommitSha(f.headSha);

      final unknown = await sut.getFileBytes(
          repo, FileRevisionAtCommit(root), 'nope.png');
      expect(unknown.exists, isFalse);
      expect(unknown.sizeBytes, 0);

      final rootParent = await sut.getFileBytes(
          repo, FileRevisionParentOfCommit(root), 'file_0.txt');
      expect(rootParent.exists, isFalse);

      final noDisk = await sut.getFileBytes(
          repo, const FileRevisionWorkingTree(), 'nope.png');
      expect(noDisk.exists, isFalse);
    } finally {
      await f.dispose();
    }
  });

  test('maxBytes cap returns size only (no bytes)', () async {
    final f = await RepoFixture.withLinearHistory(1);
    try {
      final sut = GitCliReadOperations();
      final repo = loc(f);
      final capped = await sut.getFileBytes(
        repo,
        const FileRevisionHead(),
        'file_0.txt',
        maxBytes: 2,
      );
      expect(capped.exists, isTrue);
      expect(capped.bytes, isNull);
      expect(capped.tooLarge, isTrue);
      expect(capped.sizeBytes, greaterThan(2));
    } finally {
      await f.dispose();
    }
  });
}
