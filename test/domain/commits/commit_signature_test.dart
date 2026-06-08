import 'package:flutter_test/flutter_test.dart';
import 'package:gitopen/domain/commits/commit_signature.dart';

void main() {
  group('CommitSignature', () {
    final when = DateTime.utc(2026, 6, 8, 10, 30);

    CommitSignature build({
      String name = 'Ada',
      String email = 'ada@example.com',
      DateTime? whenValue,
    }) {
      return CommitSignature(name, email, whenValue ?? when);
    }

    test('assigns all fields from constructor', () {
      final sig = build();
      expect(sig.name, 'Ada');
      expect(sig.email, 'ada@example.com');
      expect(sig.when, when);
    });

    test('is equal when all fields match', () {
      expect(build(), build());
      expect(build().hashCode, build().hashCode);
    });

    test('differs by name', () {
      expect(build(), isNot(build(name: 'Grace')));
    });

    test('differs by email', () {
      expect(build(email: 'a@x.com'), isNot(build(email: 'b@x.com')));
    });

    test('differs by when', () {
      expect(
        build(whenValue: DateTime.utc(2026)),
        isNot(build(whenValue: DateTime.utc(2025))),
      );
    });
  });
}
