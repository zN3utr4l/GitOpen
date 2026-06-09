import 'package:flutter_test/flutter_test.dart';
import 'package:gitopen/domain/diff/merge_conflict.dart';

void main() {
  const parser = MergeConflictParser();

  /// Builds a standard two-way conflict file body.
  String twoWay({
    String before = 'line a\n',
    String ours = 'our change\n',
    String theirs = 'their change\n',
    String after = 'line z\n',
    String oursLabel = 'HEAD',
    String theirsLabel = 'feature',
  }) {
    return '$before'
        '<<<<<<< $oursLabel\n'
        '$ours'
        '=======\n'
        '$theirs'
        '>>>>>>> $theirsLabel\n'
        '$after';
  }

  group('parse — passthrough', () {
    test('file with no conflict markers yields a single plain segment', () {
      const text = 'just\nsome\nplain text\n';
      final segs = parser.parse(text);
      expect(segs, hasLength(1));
      expect(segs.single, isA<PlainSegment>());
      expect((segs.single as PlainSegment).text, text);
    });

    test('empty string yields a single empty plain segment', () {
      final segs = parser.parse('');
      expect(segs, hasLength(1));
      expect((segs.single as PlainSegment).text, '');
    });

    test('a `<<<<<<<<` (8 chars) in code is NOT treated as a marker', () {
      const text = 'a <<<<<<<< not a marker\nnext\n';
      final segs = parser.parse(text);
      expect(segs, hasLength(1));
      expect(segs.single, isA<PlainSegment>());
    });
  });

  group('parse — single conflict', () {
    test('splits into plain / conflict / plain', () {
      final segs = parser.parse(twoWay());
      expect(segs, hasLength(3));
      expect((segs[0] as PlainSegment).text, 'line a\n');
      final c = segs[1] as ConflictSegment;
      expect(c.ours, 'our change\n');
      expect(c.theirs, 'their change\n');
      expect(c.base, isNull);
      expect((segs[2] as PlainSegment).text, 'line z\n');
    });

    test('captures the ours/theirs labels', () {
      final segs = parser.parse(twoWay(oursLabel: 'main', theirsLabel: 'dev'));
      final c = segs[1] as ConflictSegment;
      expect(c.oursLabel, 'main');
      expect(c.theirsLabel, 'dev');
    });

    test('handles a conflict with empty ours side', () {
      final segs = parser.parse(twoWay(ours: ''));
      final c = segs[1] as ConflictSegment;
      expect(c.ours, '');
      expect(c.theirs, 'their change\n');
    });

    test('multi-line ours and theirs are captured intact', () {
      final segs = parser.parse(twoWay(
        ours: 'o1\no2\no3\n',
        theirs: 't1\nt2\n',
      ));
      final c = segs[1] as ConflictSegment;
      expect(c.ours, 'o1\no2\no3\n');
      expect(c.theirs, 't1\nt2\n');
    });
  });

  group('parse — multiple conflicts', () {
    test('two conflicts separated by context', () {
      const text = 'top\n'
          '<<<<<<< HEAD\n'
          'a-ours\n'
          '=======\n'
          'a-theirs\n'
          '>>>>>>> b\n'
          'middle\n'
          '<<<<<<< HEAD\n'
          'b-ours\n'
          '=======\n'
          'b-theirs\n'
          '>>>>>>> b\n'
          'bottom\n';
      final segs = parser.parse(text);
      expect(segs, hasLength(5));
      expect((segs[0] as PlainSegment).text, 'top\n');
      expect((segs[1] as ConflictSegment).ours, 'a-ours\n');
      expect((segs[2] as PlainSegment).text, 'middle\n');
      expect((segs[3] as ConflictSegment).theirs, 'b-theirs\n');
      expect((segs[4] as PlainSegment).text, 'bottom\n');
    });

    test('two adjacent conflicts with no context between them', () {
      const text = '<<<<<<< HEAD\n'
          'x\n'
          '=======\n'
          'y\n'
          '>>>>>>> b\n'
          '<<<<<<< HEAD\n'
          'p\n'
          '=======\n'
          'q\n'
          '>>>>>>> b\n';
      final segs = parser.parse(text);
      final conflicts = segs.whereType<ConflictSegment>().toList();
      expect(conflicts, hasLength(2));
      expect(conflicts[0].ours, 'x\n');
      expect(conflicts[1].theirs, 'q\n');
    });
  });

  group('parse — diff3 base', () {
    test('captures the base section when present', () {
      const text = 'ctx\n'
          '<<<<<<< HEAD\n'
          'ours\n'
          '||||||| merged common ancestor\n'
          'base\n'
          '=======\n'
          'theirs\n'
          '>>>>>>> other\n';
      final segs = parser.parse(text);
      final c = segs.whereType<ConflictSegment>().single;
      expect(c.ours, 'ours\n');
      expect(c.base, 'base\n');
      expect(c.theirs, 'theirs\n');
      expect(c.baseLabel, 'merged common ancestor');
    });

    test('base is null when the diff3 section is absent', () {
      final segs = parser.parse(twoWay());
      expect((segs[1] as ConflictSegment).base, isNull);
    });

    test('empty base section is captured as empty string (not null)', () {
      const text = '<<<<<<< HEAD\n'
          'ours\n'
          '|||||||\n'
          '=======\n'
          'theirs\n'
          '>>>>>>> other\n';
      final segs = parser.parse(text);
      final c = segs.whereType<ConflictSegment>().single;
      expect(c.base, '');
    });
  });

  group('parse — malformed', () {
    test('unterminated conflict is emitted as plain text', () {
      const text = 'a\n<<<<<<< HEAD\nours\n=======\ntheirs\n';
      final segs = parser.parse(text);
      // No closing >>>>>>>, so the whole thing stays plain (no conflict).
      expect(segs.whereType<ConflictSegment>(), isEmpty);
      // Round-trips back to the original input.
      expect(
        segs.map((s) => (s as PlainSegment).text).join(),
        text,
      );
    });

    test('lone separator without a start marker stays plain', () {
      const text = 'before\n=======\nafter\n';
      final segs = parser.parse(text);
      expect(segs.whereType<ConflictSegment>(), isEmpty);
    });
  });

  group('parse — line-ending preservation', () {
    test('CRLF terminators survive in both context and conflict sides', () {
      const text = 'top\r\n'
          '<<<<<<< HEAD\r\n'
          'ours\r\n'
          '=======\r\n'
          'theirs\r\n'
          '>>>>>>> b\r\n'
          'bottom\r\n';
      final segs = parser.parse(text);
      expect((segs[0] as PlainSegment).text, 'top\r\n');
      final c = segs[1] as ConflictSegment;
      expect(c.ours, 'ours\r\n');
      expect(c.theirs, 'theirs\r\n');
      expect((segs[2] as PlainSegment).text, 'bottom\r\n');
    });

    test('missing trailing newline on last line is preserved', () {
      final segs = parser.parse(twoWay(after: 'last line no newline'));
      expect((segs.last as PlainSegment).text, 'last line no newline');
    });
  });

  group('assembleResolution', () {
    test('no-conflict passthrough returns identical text', () {
      const text = 'plain\ntext\nhere\n';
      final segs = parser.parse(text);
      expect(assembleResolution(segs, const {}), text);
    });

    test('choosing ours removes markers and keeps our side', () {
      final segs = parser.parse(twoWay());
      final idx = segs.indexWhere((s) => s is ConflictSegment);
      final result = assembleResolution(segs, {idx: Choice.ours});
      expect(result, 'line a\nour change\nline z\n');
    });

    test('choosing theirs keeps their side', () {
      final segs = parser.parse(twoWay());
      final idx = segs.indexWhere((s) => s is ConflictSegment);
      final result = assembleResolution(segs, {idx: Choice.theirs});
      expect(result, 'line a\ntheir change\nline z\n');
    });

    test('choosing both keeps ours then theirs', () {
      final segs = parser.parse(twoWay());
      final idx = segs.indexWhere((s) => s is ConflictSegment);
      final result = assembleResolution(segs, {idx: Choice.both});
      expect(result, 'line a\nour change\ntheir change\nline z\n');
    });

    test('choosing bothReversed keeps theirs then ours', () {
      final segs = parser.parse(twoWay());
      final idx = segs.indexWhere((s) => s is ConflictSegment);
      final result = assembleResolution(segs, {idx: Choice.bothReversed});
      expect(result, 'line a\ntheir change\nour change\nline z\n');
    });

    test('per-conflict choices are applied independently', () {
      const text = '<<<<<<< HEAD\n'
          'a-ours\n'
          '=======\n'
          'a-theirs\n'
          '>>>>>>> b\n'
          'mid\n'
          '<<<<<<< HEAD\n'
          'b-ours\n'
          '=======\n'
          'b-theirs\n'
          '>>>>>>> b\n';
      final segs = parser.parse(text);
      final indices = [
        for (var i = 0; i < segs.length; i++)
          if (segs[i] is ConflictSegment) i,
      ];
      final result = assembleResolution(segs, {
        indices[0]: Choice.ours,
        indices[1]: Choice.theirs,
      });
      expect(result, 'a-ours\nmid\nb-theirs\n');
    });

    test('an unresolved conflict re-emits its original markers', () {
      final segs = parser.parse(twoWay());
      // Empty choices map → nothing resolved → output equals input.
      final result = assembleResolution(segs, const {});
      expect(result, twoWay());
    });

    test('partially resolved file keeps the unresolved conflict intact', () {
      const text = '<<<<<<< HEAD\n'
          'a-ours\n'
          '=======\n'
          'a-theirs\n'
          '>>>>>>> b\n'
          'mid\n'
          '<<<<<<< HEAD\n'
          'b-ours\n'
          '=======\n'
          'b-theirs\n'
          '>>>>>>> b\n';
      final segs = parser.parse(text);
      final indices = [
        for (var i = 0; i < segs.length; i++)
          if (segs[i] is ConflictSegment) i,
      ];
      // Resolve only the first conflict; the second must stay marked.
      final result = assembleResolution(segs, {indices[0]: Choice.ours});
      expect(result, contains('a-ours\n'));
      expect(result, isNot(contains('a-theirs')));
      expect(result, contains('<<<<<<< HEAD\nb-ours'));
      expect(result, contains('>>>>>>> b\n'));
    });

    test('round-trips a diff3 conflict choosing base via reconstruct', () {
      const text = '<<<<<<< HEAD\n'
          'ours\n'
          '||||||| base-label\n'
          'base\n'
          '=======\n'
          'theirs\n'
          '>>>>>>> other\n';
      final segs = parser.parse(text);
      // Unresolved → markers (including the base section) must round-trip.
      expect(assembleResolution(segs, const {}), text);
    });

    test('choosing ours on a CRLF conflict preserves CRLF in the result', () {
      const text = 'top\r\n'
          '<<<<<<< HEAD\r\n'
          'ours\r\n'
          '=======\r\n'
          'theirs\r\n'
          '>>>>>>> b\r\n'
          'bottom\r\n';
      final segs = parser.parse(text);
      final idx = segs.indexWhere((s) => s is ConflictSegment);
      final result = assembleResolution(segs, {idx: Choice.ours});
      expect(result, 'top\r\nours\r\nbottom\r\n');
    });
  });
}
