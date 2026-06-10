import 'package:gitopen/domain/diff/diff_line.dart';

/// One side-by-side row: deletions/context on the left (old file),
/// additions/context on the right (new file). A null side renders blank.
typedef SplitRow = ({DiffLine? left, DiffLine? right});

/// Folds unified-diff lines into side-by-side rows.
///
/// Context spans both columns; inside each changed run, the k-th deletion
/// pairs with the k-th addition and the longer side trails with blanks.
List<SplitRow> buildSplitRows(List<DiffLine> lines) {
  final rows = <SplitRow>[];
  final deletions = <DiffLine>[];
  final additions = <DiffLine>[];

  void flush() {
    final count = deletions.length > additions.length
        ? deletions.length
        : additions.length;
    for (var i = 0; i < count; i++) {
      rows.add((
        left: i < deletions.length ? deletions[i] : null,
        right: i < additions.length ? additions[i] : null,
      ));
    }
    deletions.clear();
    additions.clear();
  }

  for (final line in lines) {
    switch (line.kind) {
      case DiffLineKind.deletion:
        if (additions.isNotEmpty) flush();
        deletions.add(line);
      case DiffLineKind.addition:
        additions.add(line);
      case DiffLineKind.context:
        flush();
        rows.add((left: line, right: line));
    }
  }
  flush();
  return rows;
}
