import 'package:equatable/equatable.dart';

/// One contiguous run of a conflicted file's text after parsing.
///
/// A file is parsed into an ordered list of segments: [PlainSegment]s carry
/// text outside any conflict, [ConflictSegment]s carry the ours/theirs (and
/// optional diff3 base) sides of a single conflict region.  Re-concatenating
/// the original text of every segment, in order, reproduces the input
/// byte-for-byte (markers included) — see [MergeConflictParser.parse].
sealed class Segment extends Equatable {
  const Segment();
}

/// Text that lies outside any conflict marker — shown as read-only context in
/// the editor and emitted verbatim by [assembleResolution].
final class PlainSegment extends Segment {
  const PlainSegment(this.text);

  /// The literal text, including its line terminators.
  final String text;

  @override
  List<Object?> get props => [text];
}

/// A single `<<<<<<< … =======  … >>>>>>>` region.
///
/// Each side ([ours]/[theirs]/[base]) preserves the exact text between the
/// markers, line terminators included.  [base] is non-null only for diff3-style
/// conflicts that carry the `||||||| …` common-ancestor section.
final class ConflictSegment extends Segment {
  const ConflictSegment({
    required this.ours,
    required this.theirs,
    this.base,
    this.oursLabel = '',
    this.theirsLabel = '',
    this.baseLabel = '',
  });

  /// Text from the current branch (`<<<<<<<` … up to `|||||||`/`=======`).
  final String ours;

  /// Text from the branch being merged (`=======` … up to `>>>>>>>`).
  final String theirs;

  /// The common-ancestor text for diff3 conflicts (`|||||||` … `=======`), or
  /// `null` for the standard two-way marker form.
  final String? base;

  /// Label after the `<<<<<<<` marker (e.g. `HEAD`). Cosmetic only.
  final String oursLabel;

  /// Label after the `>>>>>>>` marker (e.g. the merged branch). Cosmetic only.
  final String theirsLabel;

  /// Label after the `|||||||` marker (diff3 only). Cosmetic only.
  final String baseLabel;

  @override
  List<Object?> get props =>
      [ours, theirs, base, oursLabel, theirsLabel, baseLabel];
}

/// Which side(s) of a conflict to keep when assembling the resolution.
enum Choice {
  /// Keep only the current-branch side.
  ours,

  /// Keep only the incoming side.
  theirs,

  /// Keep both, ours first then theirs.
  both,

  /// Keep both, theirs first then ours.
  bothReversed,
}

/// Stateless parser for git's textual conflict markers.
///
/// Recognises the standard markers git writes into the working tree:
/// ```text
/// <<<<<<< ours-label
/// ...our lines...
/// ||||||| base-label      (optional — only with merge.conflictStyle=diff3)
/// ...base lines...
/// =======
/// ...their lines...
/// >>>>>>> theirs-label
/// ```
/// A marker is only recognised at the START of a line (git always writes them
/// that way), so conflict-marker-looking text inside a code block is left
/// untouched as long as it isn't column-0.  The parser never throws: malformed
/// or unterminated markers are emitted as ordinary [PlainSegment] text so the
/// caller can fall back to an external editor.
class MergeConflictParser {
  const MergeConflictParser();

  static const String _oursPrefix = '<<<<<<<';
  static const String _basePrefix = '|||||||';
  static const String _separator = '=======';
  static const String _theirsPrefix = '>>>>>>>';

  /// Parses [content] into an ordered list of [Segment]s.
  ///
  /// The concatenation of every plain segment's text plus the reconstructed
  /// marker text of every conflict segment equals [content] exactly, so the
  /// transform is loss-free for files that round-trip through the editor
  /// without a choice being applied.  CRLF (`\r\n`) and a missing trailing
  /// newline are both preserved because the parser splits on `\n` while
  /// keeping the terminator attached to each line.
  List<Segment> parse(String content) {
    if (content.isEmpty) return const [PlainSegment('')];

    final lines = _splitKeepingTerminators(content);
    final segments = <Segment>[];
    final plain = StringBuffer();

    void flushPlain() {
      if (plain.isNotEmpty) {
        segments.add(PlainSegment(plain.toString()));
        plain.clear();
      }
    }

    var i = 0;
    while (i < lines.length) {
      final line = lines[i];
      if (!_isMarker(line, _oursPrefix)) {
        plain.write(line);
        i++;
        continue;
      }

      // Found a `<<<<<<<` at column 0. Try to consume a full conflict block.
      final block = _tryParseConflict(lines, i);
      if (block == null) {
        // Unterminated / malformed — treat the marker line as plain text and
        // keep scanning from the next line.
        plain.write(line);
        i++;
        continue;
      }
      flushPlain();
      segments.add(block.segment);
      i = block.nextIndex;
    }

    flushPlain();
    if (segments.isEmpty) segments.add(const PlainSegment(''));
    return segments;
  }

  /// Attempts to read one full conflict region starting at [start] (which must
  /// point at a `<<<<<<<` line). Returns `null` when the block is not properly
  /// terminated by a `>>>>>>>` after a `=======`.
  _ParsedBlock? _tryParseConflict(List<String> lines, int start) {
    final oursLabel = _labelAfter(lines[start], _oursPrefix);
    final ours = StringBuffer();
    final base = StringBuffer();
    final theirs = StringBuffer();
    var baseLabel = '';
    var theirsLabel = '';
    var hasBase = false;

    var section = _Section.ours;
    var i = start + 1;
    for (; i < lines.length; i++) {
      final line = lines[i];

      if (_isMarker(line, _oursPrefix)) {
        // A nested `<<<<<<<` before the current block closed means the block we
        // started is malformed; bail so the outer scanner treats it as text.
        return null;
      }
      if (section == _Section.ours && _isMarker(line, _basePrefix)) {
        hasBase = true;
        baseLabel = _labelAfter(line, _basePrefix);
        section = _Section.base;
        continue;
      }
      if ((section == _Section.ours || section == _Section.base) &&
          _isSeparator(line)) {
        section = _Section.theirs;
        continue;
      }
      if (section == _Section.theirs && _isMarker(line, _theirsPrefix)) {
        theirsLabel = _labelAfter(line, _theirsPrefix);
        return _ParsedBlock(
          ConflictSegment(
            ours: ours.toString(),
            theirs: theirs.toString(),
            base: hasBase ? base.toString() : null,
            oursLabel: oursLabel,
            theirsLabel: theirsLabel,
            baseLabel: baseLabel,
          ),
          i + 1,
        );
      }

      switch (section) {
        case _Section.ours:
          ours.write(line);
        case _Section.base:
          base.write(line);
        case _Section.theirs:
          theirs.write(line);
      }
    }

    // Ran off the end without a closing `>>>>>>>`.
    return null;
  }

  /// True when [line] begins with [prefix] at column 0 followed by a space or
  /// the end of the line (the byte after the 7 marker chars). git always writes
  /// `"<<<<<<< label"` or a bare `"======="`, so this rejects e.g. a literal
  /// `"<<<<<<<<"` (8 chars) appearing in code.
  bool _isMarker(String line, String prefix) {
    if (!line.startsWith(prefix)) return false;
    if (line.length == prefix.length) return true;
    final next = line[prefix.length];
    return next == ' ' || next == '\r' || next == '\n';
  }

  /// `=======` is the only marker with no trailing label, so it must be the
  /// bare 7 chars optionally followed by a line terminator.
  bool _isSeparator(String line) {
    if (!line.startsWith(_separator)) return false;
    final rest = line.substring(_separator.length);
    return rest.isEmpty || rest == '\r\n' || rest == '\n' || rest == '\r';
  }

  /// Extracts the trimmed label after a marker prefix (e.g. `HEAD` from
  /// `"<<<<<<< HEAD\n"`), dropping the leading space and the line terminator.
  String _labelAfter(String line, String prefix) {
    var rest = line.substring(prefix.length);
    rest = rest.replaceAll('\r', '').replaceAll('\n', '');
    return rest.trim();
  }

  /// Splits [content] on `\n` while keeping each line's terminator attached, so
  /// re-joining reproduces the original (CRLF and a missing final newline both
  /// survive).
  static List<String> _splitKeepingTerminators(String content) {
    final lines = <String>[];
    var start = 0;
    for (var i = 0; i < content.length; i++) {
      if (content[i] == '\n') {
        lines.add(content.substring(start, i + 1));
        start = i + 1;
      }
    }
    if (start < content.length) lines.add(content.substring(start));
    return lines;
  }
}

enum _Section { ours, base, theirs }

class _ParsedBlock {
  _ParsedBlock(this.segment, this.nextIndex);
  final ConflictSegment segment;
  final int nextIndex;
}

/// Re-assembles the resolved file text from [segments] and a map of
/// per-conflict [choices].
///
/// [choices] is keyed by the index of the [ConflictSegment] WITHIN
/// [segments] (i.e. its position in the full segment list, plain segments
/// included). A conflict with no entry in [choices] is left UNRESOLVED and
/// re-emitted with its original markers, so a partially-resolved save still
/// produces a valid conflicted file. Plain segments are always emitted
/// verbatim. All chosen sides have their markers stripped.
String assembleResolution(List<Segment> segments, Map<int, Choice> choices) {
  final out = StringBuffer();
  for (var i = 0; i < segments.length; i++) {
    final seg = segments[i];
    switch (seg) {
      case PlainSegment(:final text):
        out.write(text);
      case ConflictSegment():
        final choice = choices[i];
        if (choice == null) {
          out.write(_reconstructMarkers(seg));
        } else {
          out.write(_applyChoice(seg, choice));
        }
    }
  }
  return out.toString();
}

String _applyChoice(ConflictSegment seg, Choice choice) {
  return switch (choice) {
    Choice.ours => seg.ours,
    Choice.theirs => seg.theirs,
    Choice.both => '${seg.ours}${seg.theirs}',
    Choice.bothReversed => '${seg.theirs}${seg.ours}',
  };
}

/// Rebuilds the original marker text for an unresolved conflict so a partial
/// save round-trips. Uses `\n` terminators on the marker lines — git re-reads
/// them fine and an unresolved file is expected to still be edited.
String _reconstructMarkers(ConflictSegment seg) {
  final b = StringBuffer()
    ..write('<<<<<<<')
    ..write(seg.oursLabel.isEmpty ? '' : ' ${seg.oursLabel}')
    ..write('\n')
    ..write(seg.ours);
  final base = seg.base;
  if (base != null) {
    b
      ..write('|||||||')
      ..write(seg.baseLabel.isEmpty ? '' : ' ${seg.baseLabel}')
      ..write('\n')
      ..write(base);
  }
  b
    ..write('=======\n')
    ..write(seg.theirs)
    ..write('>>>>>>>')
    ..write(seg.theirsLabel.isEmpty ? '' : ' ${seg.theirsLabel}')
    ..write('\n');
  return b.toString();
}
