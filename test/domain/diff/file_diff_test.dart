import 'package:flutter_test/flutter_test.dart';
import 'package:gitopen/domain/diff/diff_hunk.dart';
import 'package:gitopen/domain/diff/diff_line.dart';
import 'package:gitopen/domain/diff/file_diff.dart';

void main() {
  group('FileDiff', () {
    const hunk = DiffHunk(
      oldStart: 1,
      oldCount: 1,
      newStart: 1,
      newCount: 1,
      header: '@@ -1 +1 @@',
      lines: [DiffLine(kind: DiffLineKind.context, content: 'x')],
    );

    FileDiff build({
      String path = 'lib/main.dart',
      String? oldPath,
      FileChangeKind changeKind = FileChangeKind.modified,
      bool isBinary = false,
      int linesAdded = 1,
      int linesDeleted = 1,
      List<DiffHunk> hunks = const [hunk],
    }) {
      return FileDiff(
        path: path,
        oldPath: oldPath,
        changeKind: changeKind,
        isBinary: isBinary,
        linesAdded: linesAdded,
        linesDeleted: linesDeleted,
        hunks: hunks,
      );
    }

    test('assigns all fields from constructor', () {
      final diff = build(
        oldPath: 'lib/old.dart',
        changeKind: FileChangeKind.renamed,
      );
      expect(diff.path, 'lib/main.dart');
      expect(diff.oldPath, 'lib/old.dart');
      expect(diff.changeKind, FileChangeKind.renamed);
      expect(diff.isBinary, isFalse);
      expect(diff.linesAdded, 1);
      expect(diff.linesDeleted, 1);
      expect(diff.hunks, [hunk]);
    });

    test('allows null oldPath', () {
      expect(build().oldPath, isNull);
    });

    test('exposes the expected enum values', () {
      expect(FileChangeKind.values, [
        FileChangeKind.added,
        FileChangeKind.deleted,
        FileChangeKind.modified,
        FileChangeKind.renamed,
        FileChangeKind.copied,
        FileChangeKind.typeChanged,
        FileChangeKind.unmerged,
      ]);
    });

    test('is equal when all fields match', () {
      expect(build(), build());
      expect(build().hashCode, build().hashCode);
    });

    test('differs by path', () {
      expect(build(path: 'a'), isNot(build(path: 'b')));
    });

    test('differs by oldPath', () {
      expect(build(oldPath: 'a'), isNot(build(oldPath: 'b')));
    });

    test('differs by changeKind', () {
      expect(
        build(changeKind: FileChangeKind.added),
        isNot(build(changeKind: FileChangeKind.deleted)),
      );
    });

    test('differs by isBinary', () {
      expect(build(), isNot(build(isBinary: true)));
    });

    test('differs by linesAdded', () {
      expect(build(), isNot(build(linesAdded: 2)));
    });

    test('differs by linesDeleted', () {
      expect(build(), isNot(build(linesDeleted: 2)));
    });

    test('differs by hunks', () {
      expect(build(), isNot(build(hunks: const [])));
    });
  });
}
