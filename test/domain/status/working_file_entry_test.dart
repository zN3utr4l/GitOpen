import 'package:flutter_test/flutter_test.dart';
import 'package:gitopen/domain/status/working_file_entry.dart';

void main() {
  group('WorkingFileEntry', () {
    WorkingFileEntry build({
      String path = 'lib/main.dart',
      WorkingFileState indexState = WorkingFileState.modified,
      WorkingFileState workingTreeState = WorkingFileState.unmodified,
      String? oldPath,
    }) {
      return WorkingFileEntry(
        path: path,
        indexState: indexState,
        workingTreeState: workingTreeState,
        oldPath: oldPath,
      );
    }

    test('assigns all fields from constructor', () {
      final entry = build(
        oldPath: 'lib/old.dart',
        workingTreeState: WorkingFileState.renamed,
      );
      expect(entry.path, 'lib/main.dart');
      expect(entry.indexState, WorkingFileState.modified);
      expect(entry.workingTreeState, WorkingFileState.renamed);
      expect(entry.oldPath, 'lib/old.dart');
    });

    test('allows null oldPath', () {
      expect(build().oldPath, isNull);
    });

    test('exposes the expected enum values', () {
      expect(WorkingFileState.values, [
        WorkingFileState.unmodified,
        WorkingFileState.added,
        WorkingFileState.modified,
        WorkingFileState.deleted,
        WorkingFileState.renamed,
        WorkingFileState.conflicted,
        WorkingFileState.untracked,
        WorkingFileState.ignored,
      ]);
    });

    test('is equal when all fields match', () {
      expect(build(), build());
      expect(build().hashCode, build().hashCode);
    });

    test('differs by path', () {
      expect(build(path: 'a'), isNot(build(path: 'b')));
    });

    test('differs by indexState', () {
      expect(
        build(indexState: WorkingFileState.added),
        isNot(build(indexState: WorkingFileState.deleted)),
      );
    });

    test('differs by workingTreeState', () {
      expect(
        build(workingTreeState: WorkingFileState.added),
        isNot(build(workingTreeState: WorkingFileState.deleted)),
      );
    });

    test('differs by oldPath', () {
      expect(build(oldPath: 'a'), isNot(build(oldPath: 'b')));
    });
  });
}
