import 'package:flutter_test/flutter_test.dart';
import 'package:gitopen/application/commit_graph/commit_graph_layout.dart';
import 'package:gitopen/domain/commits/commit_info.dart';
import 'package:gitopen/domain/commits/commit_sha.dart';
import 'package:gitopen/domain/commits/commit_signature.dart';

CommitInfo mk(String sha, [List<String> parents = const []]) {
  final pad = sha.padLeft(8, '0');
  final sig = CommitSignature('a', 'a@x', DateTime.utc(2024));
  return CommitInfo(
    sha: CommitSha(pad),
    parentShas: parents.map((p) => CommitSha(p.padLeft(8, '0'))).toList(),
    author: sig,
    committer: sig,
    summary: 'msg',
    message: 'msg',
  );
}

void main() {
  group('CommitGraphLayout', () {
    test('linear history all in lane 0', () {
      final commits = [mk('c', ['b']), mk('b', ['a']), mk('a')];
      final nodes = const DefaultCommitGraphLayout().compute(commits);
      expect(nodes, hasLength(3));
      expect(nodes.every((n) => n.lane == 0), isTrue);
    });

    test('branch creates two lanes; root collapses back', () {
      final commits = [
        mk('c',  ['b1', 'b2']),
        mk('b1', ['a']),
        mk('b2', ['a']),
        mk('a'),
      ];
      final nodes = const DefaultCommitGraphLayout().compute(commits);
      final lanes = nodes.map((n) => n.lane).toSet();
      expect(lanes, containsAll([0, 1]));
      expect(nodes.last.lane, 0);
    });

    test('empty input returns empty', () {
      expect(const DefaultCommitGraphLayout().compute(const []), isEmpty);
    });

    test('first-parent chain keeps a single strand colour', () {
      // c -> b -> a, linear. The strand must have one colour throughout.
      final commits = [mk('c', ['b']), mk('b', ['a']), mk('a')];
      final nodes = const DefaultCommitGraphLayout().compute(commits);
      final colors = nodes.map((n) => n.color).toSet();
      expect(colors, hasLength(1));
    });

    test('merge-in branch gets a distinct colour from trunk', () {
      // m = merge(p1, f1); p1 -> b; f1 -> b; b root.
      // m and p1 share the trunk colour; f1 must be a different colour.
      final commits = [
        mk('m', ['p1', 'f1']),
        mk('p1', ['b']),
        mk('f1', ['b']),
        mk('b'),
      ];
      final nodes = const DefaultCommitGraphLayout().compute(commits);
      final byName = {for (final n in nodes) n.commit.sha.value.trim(): n};
      final m = byName.entries.firstWhere((e) => e.key.endsWith('m')).value;
      final p1 = byName.entries.firstWhere((e) => e.key.endsWith('p1')).value;
      final f1 = byName.entries.firstWhere((e) => e.key.endsWith('f1')).value;
      expect(m.color, p1.color, reason: 'trunk colour must persist into p1');
      expect(f1.color, isNot(m.color),
          reason: 'merged-in branch must have its own colour');
    });

    test('lane reused for unrelated branch gets a fresh colour', () {
      // First strand: c -> b -> a (ends).
      // Then unrelated tip x with parent y appears: x sits on lane 0
      // (since lane 0 was freed by `a`), but its colour must differ.
      final commits = [
        mk('c', ['b']),
        mk('b', ['a']),
        mk('a'),
        mk('x', ['y']),
        mk('y'),
      ];
      final nodes = const DefaultCommitGraphLayout().compute(commits);
      final c = nodes.firstWhere((n) => n.commit.sha.value.endsWith('c'));
      final x = nodes.firstWhere((n) => n.commit.sha.value.endsWith('x'));
      expect(x.lane, 0, reason: 'lane 0 should be reused after `a` frees it');
      expect(x.color, isNot(c.color),
          reason: 'fresh strand must receive a fresh colour');
    });

    test('merge-back to fork point preserves trunk pass-through', () {
      // m = merge(p1, f1); p1 -> b; f1 -> b; b -> root.
      // At f1's row, the trunk (waiting for b on lane 0) must keep its
      // colour as a vertical pass-through, and f1's edge down to lane 0
      // must use f1's strand colour.
      final commits = [
        mk('m', ['p1', 'f1']),
        mk('p1', ['b']),
        mk('f1', ['b']),
        mk('b'),
      ];
      final nodes = const DefaultCommitGraphLayout().compute(commits);
      final f1 = nodes.firstWhere((n) => n.commit.sha.value.endsWith('f1'));
      final m = nodes.firstWhere((n) => n.commit.sha.value.endsWith('m'));
      // Trunk pass-through: a vertical (0,0) segment with the trunk colour.
      final trunkPass = f1.bottomSegments.where(
          (s) => s.fromLane == 0 && s.toLane == 0 && s.color == m.color);
      expect(trunkPass, isNotEmpty,
          reason: 'trunk must keep its colour passing through f1');
      // f1's edge curves from its own lane down to lane 0 in f1's colour.
      final tail = f1.bottomSegments.where(
          (s) => s.fromLane == f1.lane && s.toLane == 0 && s.color == f1.color);
      expect(tail, isNotEmpty,
          reason: 'f1 must tail into the fork point in its own colour');
    });
  });
}
