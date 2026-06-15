import 'package:flutter_test/flutter_test.dart';
import 'package:gitopen/application/commits/co_authors.dart';

void main() {
  group('parseCoAuthors', () {
    test('returns empty when there are no trailers', () {
      expect(parseCoAuthors('Fix the bug\n\nA normal body.'), isEmpty);
    });

    test('parses a single Co-authored-by trailer', () {
      const message = 'Add feature\n\nCo-authored-by: Ada <ada@example.com>';
      expect(parseCoAuthors(message), [
        (name: 'Ada', email: 'ada@example.com'),
      ]);
    });

    test('parses multiple trailers and is case-insensitive', () {
      const message =
          'Title\n\nbody\n'
          'Co-Authored-By: Ada <ada@example.com>\n'
          'co-authored-by: Claude Fable 5 <noreply@anthropic.com>\n';
      expect(parseCoAuthors(message), [
        (name: 'Ada', email: 'ada@example.com'),
        (name: 'Claude Fable 5', email: 'noreply@anthropic.com'),
      ]);
    });

    test('de-duplicates by email (case-insensitive), keeping the first', () {
      const message =
          'T\n\n'
          'Co-authored-by: Ada <ada@example.com>\n'
          'Co-authored-by: Ada L. <ADA@example.com>\n';
      expect(parseCoAuthors(message), [
        (name: 'Ada', email: 'ada@example.com'),
      ]);
    });

    test('ignores malformed trailers without an email', () {
      const message = 'T\n\nCo-authored-by: Nobody\n';
      expect(parseCoAuthors(message), isEmpty);
    });
  });
}
