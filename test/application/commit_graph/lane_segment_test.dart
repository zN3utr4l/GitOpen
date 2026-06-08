import 'package:flutter_test/flutter_test.dart';
import 'package:gitopen/application/commit_graph/lane_segment.dart';

void main() {
  group('LaneSegment', () {
    test('exposes positional fields', () {
      const segment = LaneSegment(1, 2, 3);
      expect(segment.fromLane, 1);
      expect(segment.toLane, 2);
      expect(segment.color, 3);
    });

    test('value equality on (fromLane, toLane, color)', () {
      const a = LaneSegment(0, 1, 4);
      const b = LaneSegment(0, 1, 4);
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('differs when any field differs', () {
      const base = LaneSegment(0, 1, 4);
      expect(base, isNot(const LaneSegment(9, 1, 4)));
      expect(base, isNot(const LaneSegment(0, 9, 4)));
      expect(base, isNot(const LaneSegment(0, 1, 9)));
    });

    test('props reflect all three fields', () {
      const segment = LaneSegment(2, 5, 7);
      expect(segment.props, [2, 5, 7]);
    });
  });
}
