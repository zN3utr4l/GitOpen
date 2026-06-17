import 'package:flutter_test/flutter_test.dart';
import 'package:gitopen/infrastructure/auth/github_user_service.dart';

void main() {
  group('githubNoreplyEmails', () {
    test('produces modern and legacy forms, lowercased', () {
      expect(
        githubNoreplyEmails(id: 583231, login: 'Octocat'),
        {
          '583231+octocat@users.noreply.github.com',
          'octocat@users.noreply.github.com',
        },
      );
    });
  });

  group('accountEmails', () {
    test('unions public, verified and noreply, all normalized', () {
      final e = accountEmails(
        id: 42,
        login: 'Alice',
        publicEmail: 'Alice@Example.COM ',
        verified: ['alice@work.com', ''],
      );
      expect(e, {
        'alice@example.com',
        'alice@work.com',
        '42+alice@users.noreply.github.com',
        'alice@users.noreply.github.com',
      });
    });

    test('returns empty when nothing is provided', () {
      expect(accountEmails(), isEmpty);
    });

    test('skips noreply forms when id or login is missing', () {
      expect(accountEmails(login: 'alice'), isEmpty);
      expect(accountEmails(id: 1), isEmpty);
    });
  });
}
