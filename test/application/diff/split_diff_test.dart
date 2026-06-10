import 'package:flutter_test/flutter_test.dart';
import 'package:gitopen/application/diff/split_diff.dart';
import 'package:gitopen/domain/diff/diff_line.dart';

DiffLine _l(DiffLineKind kind, String content) =>
    DiffLine(kind: kind, content: content);

void main() {
  test('context lines occupy both sides', () {
    final rows = buildSplitRows([_l(DiffLineKind.context, 'a')]);

    expect(rows.single.left?.content, 'a');
    expect(rows.single.right?.content, 'a');
  });

  test('paired deletion/addition share one row', () {
    final rows = buildSplitRows([
      _l(DiffLineKind.deletion, 'old'),
      _l(DiffLineKind.addition, 'new'),
    ]);

    expect(rows, hasLength(1));
    expect(rows.single.left?.content, 'old');
    expect(rows.single.right?.content, 'new');
  });

  test('unbalanced run pads the short side', () {
    final rows = buildSplitRows([
      _l(DiffLineKind.deletion, 'a'),
      _l(DiffLineKind.deletion, 'b'),
      _l(DiffLineKind.addition, 'x'),
    ]);

    expect(rows, hasLength(2));
    expect(rows[0].left?.content, 'a');
    expect(rows[0].right?.content, 'x');
    expect(rows[1].left?.content, 'b');
    expect(rows[1].right, isNull);
  });
}
