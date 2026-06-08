import 'package:flutter_test/flutter_test.dart';
import 'package:gitopen/application/git/commit_request.dart';

void main() {
  group('CommitRequest', () {
    test('defaults: not amend, not signOff, null author fields', () {
      const request = CommitRequest(message: 'initial commit');
      expect(request.message, 'initial commit');
      expect(request.amend, isFalse);
      expect(request.signOff, isFalse);
      expect(request.authorName, isNull);
      expect(request.authorEmail, isNull);
    });

    test('carries all explicitly provided fields', () {
      const request = CommitRequest(
        message: 'fix bug',
        amend: true,
        signOff: true,
        authorName: 'Ada Lovelace',
        authorEmail: 'ada@example.com',
      );
      expect(request.message, 'fix bug');
      expect(request.amend, isTrue);
      expect(request.signOff, isTrue);
      expect(request.authorName, 'Ada Lovelace');
      expect(request.authorEmail, 'ada@example.com');
    });

    test('author name and email are independent optionals', () {
      const request = CommitRequest(
        message: 'partial author',
        authorName: 'Only Name',
      );
      expect(request.authorName, 'Only Name');
      expect(request.authorEmail, isNull);
    });
  });
}
