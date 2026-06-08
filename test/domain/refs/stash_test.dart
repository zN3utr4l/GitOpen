import 'package:flutter_test/flutter_test.dart';
import 'package:gitopen/domain/commits/commit_sha.dart';
import 'package:gitopen/domain/refs/stash.dart';

void main() {
  group('Stash', () {
    final when = DateTime.utc(2026, 6, 8, 12);

    Stash build({
      int index = 0,
      String sha = 'abcdef1',
      String message = 'WIP on main',
      DateTime? createdAt,
    }) {
      return Stash(
        index: index,
        sha: CommitSha(sha),
        message: message,
        createdAt: createdAt ?? when,
      );
    }

    test('assigns all fields from constructor', () {
      final stash = build();
      expect(stash.index, 0);
      expect(stash.sha, CommitSha('abcdef1'));
      expect(stash.message, 'WIP on main');
      expect(stash.createdAt, when);
    });

    test('is equal when all fields match', () {
      expect(build(), build());
      expect(build().hashCode, build().hashCode);
    });

    test('differs by index', () {
      expect(build(), isNot(build(index: 1)));
    });

    test('differs by sha', () {
      expect(build(sha: 'aaaa111'), isNot(build(sha: 'bbbb222')));
    });

    test('differs by message', () {
      expect(build(message: 'a'), isNot(build(message: 'b')));
    });

    test('differs by createdAt', () {
      expect(
        build(createdAt: DateTime.utc(2026)),
        isNot(build(createdAt: DateTime.utc(2025))),
      );
    });
  });
}
