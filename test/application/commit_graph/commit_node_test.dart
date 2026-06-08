import 'package:flutter_test/flutter_test.dart';
import 'package:gitopen/application/commit_graph/commit_node.dart';
import 'package:gitopen/application/commit_graph/lane_segment.dart';
import 'package:gitopen/domain/commits/commit_info.dart';
import 'package:gitopen/domain/commits/commit_sha.dart';
import 'package:gitopen/domain/commits/commit_signature.dart';

CommitInfo _commit(String sha) {
  final signature = CommitSignature(
    'Ada',
    'ada@example.com',
    DateTime.utc(2024),
  );
  return CommitInfo(
    sha: CommitSha(sha),
    parentShas: const [],
    author: signature,
    committer: signature,
    summary: 'summary',
    message: 'message',
  );
}

void main() {
  group('CommitNode', () {
    test('exposes its fields', () {
      final commit = _commit('abcd1234');
      final node = CommitNode(
        commit: commit,
        lane: 2,
        color: 5,
        topSegments: const [LaneSegment(0, 2, 5)],
        bottomSegments: const [LaneSegment(2, 0, 5)],
      );
      expect(node.commit, commit);
      expect(node.lane, 2);
      expect(node.color, 5);
      expect(node.topSegments, const [LaneSegment(0, 2, 5)]);
      expect(node.bottomSegments, const [LaneSegment(2, 0, 5)]);
    });

    test('value equality across all props', () {
      final commit = _commit('abcd1234');
      final a = CommitNode(
        commit: commit,
        lane: 1,
        color: 3,
        topSegments: const [LaneSegment(0, 1, 3)],
        bottomSegments: const [],
      );
      final b = CommitNode(
        commit: commit,
        lane: 1,
        color: 3,
        topSegments: const [LaneSegment(0, 1, 3)],
        bottomSegments: const [],
      );
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('differs when lane differs', () {
      final commit = _commit('abcd1234');
      final a = CommitNode(
        commit: commit,
        lane: 0,
        color: 1,
        topSegments: const [],
        bottomSegments: const [],
      );
      final b = CommitNode(
        commit: commit,
        lane: 1,
        color: 1,
        topSegments: const [],
        bottomSegments: const [],
      );
      expect(a, isNot(b));
    });

    test('differs when segment lists differ', () {
      final commit = _commit('abcd1234');
      final a = CommitNode(
        commit: commit,
        lane: 0,
        color: 1,
        topSegments: const [LaneSegment(0, 0, 1)],
        bottomSegments: const [],
      );
      final b = CommitNode(
        commit: commit,
        lane: 0,
        color: 1,
        topSegments: const [],
        bottomSegments: const [],
      );
      expect(a, isNot(b));
    });

    test('props enumerates all five fields', () {
      final commit = _commit('abcd1234');
      final node = CommitNode(
        commit: commit,
        lane: 4,
        color: 6,
        topSegments: const [],
        bottomSegments: const [],
      );
      expect(node.props, [
        commit,
        4,
        6,
        const <LaneSegment>[],
        const <LaneSegment>[],
      ]);
    });
  });
}
