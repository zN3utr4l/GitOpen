import 'package:flutter_test/flutter_test.dart';
import 'package:gitopen/domain/commits/commit_sha.dart';
import 'package:gitopen/domain/refs/tag.dart';

void main() {
  group('Tag', () {
    Tag build({
      String name = 'v1.0',
      String fullName = 'refs/tags/v1.0',
      String targetSha = 'abcdef1',
      bool isAnnotated = false,
    }) {
      return Tag(
        name: name,
        fullName: fullName,
        targetSha: CommitSha(targetSha),
        isAnnotated: isAnnotated,
      );
    }

    test('assigns all fields from constructor', () {
      final tag = build(isAnnotated: true);
      expect(tag.name, 'v1.0');
      expect(tag.fullName, 'refs/tags/v1.0');
      expect(tag.targetSha, CommitSha('abcdef1'));
      expect(tag.isAnnotated, isTrue);
    });

    test('is equal when all fields match', () {
      expect(build(), build());
      expect(build().hashCode, build().hashCode);
    });

    test('differs by name', () {
      expect(build(), isNot(build(name: 'v2.0')));
    });

    test('differs by fullName', () {
      expect(
        build(),
        isNot(build(fullName: 'refs/tags/v2.0')),
      );
    });

    test('differs by targetSha', () {
      expect(
        build(targetSha: 'aaaa111'),
        isNot(build(targetSha: 'bbbb222')),
      );
    });

    test('differs by isAnnotated', () {
      expect(build(), isNot(build(isAnnotated: true)));
    });
  });
}
