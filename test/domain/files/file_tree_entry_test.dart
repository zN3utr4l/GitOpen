import 'package:flutter_test/flutter_test.dart';
import 'package:gitopen/domain/commits/commit_sha.dart';
import 'package:gitopen/domain/files/file_tree_entry.dart';

void main() {
  group('FileTreeEntry', () {
    FileTreeEntry build({
      String name = 'main.dart',
      String fullPath = 'lib/main.dart',
      FileTreeKind kind = FileTreeKind.blob,
      int? sizeBytes = 128,
      String? commit = 'abcdef1',
    }) {
      return FileTreeEntry(
        name: name,
        fullPath: fullPath,
        kind: kind,
        sizeBytes: sizeBytes,
        containingCommit: commit == null ? null : CommitSha(commit),
      );
    }

    test('assigns all fields from constructor', () {
      final entry = build();
      expect(entry.name, 'main.dart');
      expect(entry.fullPath, 'lib/main.dart');
      expect(entry.kind, FileTreeKind.blob);
      expect(entry.sizeBytes, 128);
      expect(entry.containingCommit, CommitSha('abcdef1'));
    });

    test('allows null optional fields', () {
      const entry = FileTreeEntry(
        name: 'lib',
        fullPath: 'lib',
        kind: FileTreeKind.tree,
      );
      expect(entry.sizeBytes, isNull);
      expect(entry.containingCommit, isNull);
    });

    test('exposes the expected enum values', () {
      expect(FileTreeKind.values, [
        FileTreeKind.blob,
        FileTreeKind.tree,
        FileTreeKind.submodule,
        FileTreeKind.symlink,
      ]);
    });

    test('is equal when all fields match', () {
      expect(build(), build());
      expect(build().hashCode, build().hashCode);
    });

    test('differs by name', () {
      expect(build(name: 'a'), isNot(build(name: 'b')));
    });

    test('differs by fullPath', () {
      expect(build(fullPath: 'a'), isNot(build(fullPath: 'b')));
    });

    test('differs by kind', () {
      expect(
        build(),
        isNot(build(kind: FileTreeKind.tree)),
      );
    });

    test('differs by sizeBytes', () {
      expect(build(sizeBytes: 1), isNot(build(sizeBytes: 2)));
    });

    test('differs by containingCommit', () {
      expect(
        build(commit: 'aaaa111'),
        isNot(build(commit: 'bbbb222')),
      );
    });
  });
}
