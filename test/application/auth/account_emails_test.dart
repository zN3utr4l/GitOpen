import 'package:flutter_test/flutter_test.dart';
import 'package:gitopen/application/auth/account_emails.dart';
import 'package:gitopen/application/auth/auth_spec.dart';

void main() {
  group('githubApiToken', () {
    test('returns the token for PAT and OAuth, null for the rest', () {
      expect(
        githubApiToken(const AuthHttpsPat(username: 'a', token: 't')),
        't',
      );
      expect(githubApiToken(const AuthGitHubOauth('gho_x')), 'gho_x');
      expect(githubApiToken(const AuthSsh(privateKeyPath: '/k')), isNull);
      expect(
        githubApiToken(const AuthHttpsBasic(username: 'a', password: 'p')),
        isNull,
      );
      expect(githubApiToken(const AuthSystemDefault()), isNull);
    });
  });

  group('populatedEmails', () {
    test('unions current with fetched for a github PAT', () async {
      final result = await populatedEmails(
        host: 'github.com',
        spec: const AuthHttpsPat(username: 'a', token: 't'),
        current: {'old@x.com'},
        fetch: (token) async {
          expect(token, 't');
          return {'new@x.com'};
        },
      );
      expect(result, {'old@x.com', 'new@x.com'});
    });

    test('returns current unchanged for a non-github host without fetching',
        () async {
      var called = false;
      final result = await populatedEmails(
        host: 'gitlab.com',
        spec: const AuthHttpsPat(username: 'a', token: 't'),
        current: {'keep@x.com'},
        fetch: (_) async {
          called = true;
          return {'x@x.com'};
        },
      );
      expect(result, {'keep@x.com'});
      expect(called, isFalse);
    });

    test('returns current unchanged when the spec has no API token', () async {
      final result = await populatedEmails(
        host: 'github.com',
        spec: const AuthSsh(privateKeyPath: '/k'),
        current: {'keep@x.com'},
        fetch: (_) async => {'x@x.com'},
      );
      expect(result, {'keep@x.com'});
    });
  });
}
