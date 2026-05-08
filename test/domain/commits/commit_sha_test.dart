import 'package:flutter_test/flutter_test.dart';
import 'package:gitopen/domain/commits/commit_sha.dart';

void main() {
  group('CommitSha', () {
    test('rejects empty input', () {
      expect(() => CommitSha(''), throwsArgumentError);
      expect(() => CommitSha('   '), throwsArgumentError);
    });

    test('rejects too short', () {
      expect(() => CommitSha('abc'), throwsArgumentError);
    });

    test('rejects too long', () {
      expect(() => CommitSha('a' * 41), throwsArgumentError);
    });

    test('lowercases value', () {
      expect(CommitSha('ABCDEF1234').value, 'abcdef1234');
    });

    test('short returns first seven by default', () {
      expect(CommitSha('abcdef1234567890').short(), 'abcdef1');
    });

    test('short with explicit length', () {
      expect(CommitSha('abcdef1234567890').short(4), 'abcd');
    });

    test('equality is case-insensitive', () {
      expect(CommitSha('ABC123DEF456'), CommitSha('abc123def456'));
    });
  });
}
