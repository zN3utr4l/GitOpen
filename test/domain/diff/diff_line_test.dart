import 'package:flutter_test/flutter_test.dart';
import 'package:gitopen/domain/diff/diff_line.dart';

void main() {
  group('DiffLine', () {
    DiffLine build({
      DiffLineKind kind = DiffLineKind.context,
      String content = 'line',
      int? oldLine = 1,
      int? newLine = 1,
    }) {
      return DiffLine(
        kind: kind,
        content: content,
        oldLine: oldLine,
        newLine: newLine,
      );
    }

    test('assigns all fields from constructor', () {
      final line = build(kind: DiffLineKind.addition, content: 'hello');
      expect(line.kind, DiffLineKind.addition);
      expect(line.content, 'hello');
      expect(line.oldLine, 1);
      expect(line.newLine, 1);
    });

    test('allows null line numbers', () {
      const line = DiffLine(kind: DiffLineKind.context, content: 'x');
      expect(line.oldLine, isNull);
      expect(line.newLine, isNull);
    });

    test('exposes the expected enum values', () {
      expect(DiffLineKind.values, [
        DiffLineKind.context,
        DiffLineKind.addition,
        DiffLineKind.deletion,
      ]);
    });

    test('is equal when all fields match', () {
      expect(build(), build());
      expect(build().hashCode, build().hashCode);
    });

    test('differs by kind', () {
      expect(
        build(kind: DiffLineKind.addition),
        isNot(build(kind: DiffLineKind.deletion)),
      );
    });

    test('differs by oldLine', () {
      expect(build(), isNot(build(oldLine: 2)));
    });

    test('differs by newLine', () {
      expect(build(), isNot(build(newLine: 2)));
    });

    test('differs by content', () {
      expect(build(content: 'a'), isNot(build(content: 'b')));
    });
  });
}
