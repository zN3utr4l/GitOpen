import 'package:flutter_test/flutter_test.dart';
import 'package:gitopen/domain/diff/diff_result.dart';
import 'package:gitopen/domain/diff/file_diff.dart';

void main() {
  group('DiffResult', () {
    const fileDiff = FileDiff(
      path: 'lib/main.dart',
      changeKind: FileChangeKind.modified,
      isBinary: false,
      linesAdded: 1,
      linesDeleted: 0,
      hunks: [],
    );

    test('assigns files from constructor', () {
      const result = DiffResult(files: [fileDiff]);
      expect(result.files, [fileDiff]);
    });

    test('is equal when files match', () {
      expect(
        const DiffResult(files: [fileDiff]),
        const DiffResult(files: [fileDiff]),
      );
      expect(
        const DiffResult(files: [fileDiff]).hashCode,
        const DiffResult(files: [fileDiff]).hashCode,
      );
    });

    test('differs by files', () {
      expect(
        const DiffResult(files: [fileDiff]),
        isNot(const DiffResult(files: [])),
      );
    });
  });
}
