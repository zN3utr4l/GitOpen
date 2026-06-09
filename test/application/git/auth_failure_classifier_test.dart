import 'package:flutter_test/flutter_test.dart';
import 'package:gitopen/application/git/auth_failure_classifier.dart';

void main() {
  const c = AuthFailureClassifier();

  group('AuthFailureClassifier — authRequired', () {
    const authStderrs = [
      'fatal: Authentication failed for https://github.com/x/y.git',
      'fatal: Invalid username or password',
      'fatal: could not read Username for https://github.com: terminal prompts disabled',
      'fatal: could not read Password for https://github.com',
      'fatal: terminal prompts disabled',
      'error: HTTP Basic: Access denied',
      'remote: Invalid credentials',
      'remote: denied access',
      'git@github.com: Permission denied (publickey).',
      'The requested URL returned error: 401',
      'The requested URL returned error: 403',
    ];
    for (final s in authStderrs) {
      test('matches: ${s.split('\n').first}', () {
        expect(c.classify(s), AuthFailureReason.authRequired);
      });
    }

    test('is case-insensitive', () {
      expect(
        c.classify('FATAL: AUTHENTICATION FAILED'),
        AuthFailureReason.authRequired,
      );
    });
  });

  group('AuthFailureClassifier — wrongAccount', () {
    const wrongAccountStderrs = [
      'remote: Repository not found.\nfatal: repository not found',
      'remote: Not Found',
      'The requested URL returned error: 404',
    ];
    for (final s in wrongAccountStderrs) {
      test('matches: ${s.split('\n').first}', () {
        expect(c.classify(s), AuthFailureReason.wrongAccount);
      });
    }
  });

  group('AuthFailureClassifier — not auth-related (null)', () {
    const benign = [
      '',
      'fatal: not a git repository',
      'error: Your local changes would be overwritten by merge',
      'CONFLICT (content): Merge conflict in file.txt',
      "fatal: couldn't find remote ref main",
    ];
    for (final s in benign) {
      test('null for: ${s.isEmpty ? '(empty)' : s}', () {
        expect(c.classify(s), isNull);
      });
    }

    test('does NOT match the bare word "Authorization" (argv false-positive)',
        () {
      // The credential helper puts `http.extraheader=Authorization:` into the
      // argv; that text must never be read as an auth failure on its own.
      expect(
        c.classify('http.extraheader=Authorization: Basic <redacted>'),
        isNull,
      );
    });
  });

  group('AuthFailureClassifier — precedence', () {
    test('authRequired wins when both auth and wrong-account phrases present',
        () {
      expect(
        c.classify('Authentication failed\nrepository not found'),
        AuthFailureReason.authRequired,
      );
    });
  });
}
