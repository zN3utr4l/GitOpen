import 'package:flutter_test/flutter_test.dart';
import 'package:gitopen/domain/diff/diff_hunk.dart';
import 'package:gitopen/domain/diff/diff_line.dart';

void main() {
  group('DiffHunk', () {
    const line = DiffLine(kind: DiffLineKind.context, content: 'x');

    DiffHunk build({
      int oldStart = 1,
      int oldCount = 2,
      int newStart = 1,
      int newCount = 3,
      String header = '@@ -1,2 +1,3 @@',
      List<DiffLine> lines = const [line],
    }) {
      return DiffHunk(
        oldStart: oldStart,
        oldCount: oldCount,
        newStart: newStart,
        newCount: newCount,
        header: header,
        lines: lines,
      );
    }

    test('assigns all fields from constructor', () {
      final hunk = build();
      expect(hunk.oldStart, 1);
      expect(hunk.oldCount, 2);
      expect(hunk.newStart, 1);
      expect(hunk.newCount, 3);
      expect(hunk.header, '@@ -1,2 +1,3 @@');
      expect(hunk.lines, [line]);
    });

    test('is equal when all fields match', () {
      expect(build(), build());
      expect(build().hashCode, build().hashCode);
    });

    test('differs by oldStart', () {
      expect(build(), isNot(build(oldStart: 2)));
    });

    test('differs by oldCount', () {
      expect(build(oldCount: 1), isNot(build()));
    });

    test('differs by newStart', () {
      expect(build(), isNot(build(newStart: 2)));
    });

    test('differs by newCount', () {
      expect(build(newCount: 1), isNot(build(newCount: 2)));
    });

    test('differs by header', () {
      expect(build(header: 'a'), isNot(build(header: 'b')));
    });

    test('differs by lines', () {
      expect(build(), isNot(build(lines: const [])));
    });
  });
}
