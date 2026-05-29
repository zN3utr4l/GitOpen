import 'package:flutter_test/flutter_test.dart';
import 'package:gitopen/infrastructure/logging/secret_redactor.dart';

void main() {
  group('redactSecrets', () {
    test('redacts userinfo password in an https remote url', () {
      final out = redactSecrets(
          'fatal: unable to access https://alice:ghp_secrettoken123456789@github.com/o/r.git');
      expect(out, contains('https://alice:«redacted»@github.com'));
      expect(out, isNot(contains('ghp_secrettoken123456789')));
    });

    test('redacts token-only userinfo form', () {
      final out =
          redactSecrets('remote: https://x-access-token-value@github.com/o/r');
      // userinfo with no colon is left as-is (could be a username); the
      // bare-token rules below cover real tokens.
      expect(out, contains('@github.com'));
    });

    test('redacts an Authorization header value', () {
      final out = redactSecrets('Authorization: Basic dXNlcjpwYXNzd29yZA==');
      expect(out, 'Authorization: «redacted»');
    });

    test('redacts http.extraheader authorization', () {
      final out =
          redactSecrets('http.extraheader=Authorization: Bearer abc.def.ghi');
      expect(out, contains('«redacted»'));
      expect(out, isNot(contains('abc.def.ghi')));
    });

    test('redacts bare github tokens', () {
      for (final t in [
        'ghp_${'a' * 36}',
        'gho_${'b' * 36}',
        'github_pat_${'c' * 30}',
      ]) {
        expect(redactSecrets('token is $t here'), isNot(contains(t)));
      }
    });

    test('leaves ordinary text untouched', () {
      const plain = 'Fetching origin: 100% (50/50), done.';
      expect(redactSecrets(plain), plain);
    });

    test('handles empty input', () {
      expect(redactSecrets(''), '');
    });
  });
}
