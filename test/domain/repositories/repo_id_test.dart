import 'package:flutter_test/flutter_test.dart';
import 'package:gitopen/domain/repositories/repo_id.dart';

void main() {
  group('RepoId', () {
    test('assigns value from constructor', () {
      expect(const RepoId('abc').value, 'abc');
    });

    test('toString returns the value', () {
      expect(const RepoId('abc').toString(), 'abc');
    });

    test('is equal when value matches', () {
      expect(const RepoId('abc'), const RepoId('abc'));
      expect(const RepoId('abc').hashCode, const RepoId('abc').hashCode);
    });

    test('differs by value', () {
      expect(const RepoId('abc'), isNot(const RepoId('def')));
    });

    group('newId', () {
      test('produces a 32-char lowercase hex string', () {
        final id = RepoId.newId();
        expect(id.value, hasLength(32));
        expect(id.value, matches(RegExp(r'^[0-9a-f]{32}$')));
      });

      test('produces distinct values across calls', () {
        expect(RepoId.newId(), isNot(RepoId.newId()));
      });
    });
  });
}
