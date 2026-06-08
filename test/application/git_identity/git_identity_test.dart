import 'package:flutter_test/flutter_test.dart';
import 'package:gitopen/application/git_identity/git_identity.dart';

void main() {
  const identity = GitIdentity(
    label: 'Work',
    name: 'Jane Doe',
    email: 'jane@work.test',
  );

  group('GitIdentity.toJson', () {
    test('serialises all three fields', () {
      expect(identity.toJson(), {
        'label': 'Work',
        'name': 'Jane Doe',
        'email': 'jane@work.test',
      });
    });
  });

  group('GitIdentity.fromJson', () {
    test('round-trips a valid map', () {
      final parsed = GitIdentity.fromJson(identity.toJson());
      expect(parsed, identity);
    });

    test('returns null when input is not a Map', () {
      expect(GitIdentity.fromJson(null), isNull);
      expect(GitIdentity.fromJson('not a map'), isNull);
      expect(GitIdentity.fromJson(42), isNull);
      expect(GitIdentity.fromJson(<String>['a', 'b']), isNull);
    });

    test('returns null when label is missing or wrong type', () {
      expect(
        GitIdentity.fromJson({'name': 'n', 'email': 'e'}),
        isNull,
      );
      expect(
        GitIdentity.fromJson({'label': 1, 'name': 'n', 'email': 'e'}),
        isNull,
      );
    });

    test('returns null when name is missing or wrong type', () {
      expect(
        GitIdentity.fromJson({'label': 'l', 'email': 'e'}),
        isNull,
      );
      expect(
        GitIdentity.fromJson({'label': 'l', 'name': 2, 'email': 'e'}),
        isNull,
      );
    });

    test('returns null when email is missing or wrong type', () {
      expect(
        GitIdentity.fromJson({'label': 'l', 'name': 'n'}),
        isNull,
      );
      expect(
        GitIdentity.fromJson({'label': 'l', 'name': 'n', 'email': 3}),
        isNull,
      );
    });

    test('accepts a non-String-keyed Map as long as values are Strings', () {
      // fromJson only checks `raw is! Map`, then reads dynamic keys.
      final parsed = GitIdentity.fromJson(<dynamic, dynamic>{
        'label': 'Personal',
        'name': 'Me',
        'email': 'me@home.test',
      });
      expect(
        parsed,
        const GitIdentity(
          label: 'Personal',
          name: 'Me',
          email: 'me@home.test',
        ),
      );
    });
  });

  group('GitIdentity equality', () {
    test('equal when all fields match', () {
      expect(
        identity,
        const GitIdentity(
          label: 'Work',
          name: 'Jane Doe',
          email: 'jane@work.test',
        ),
      );
    });

    test('differs when any field differs', () {
      expect(
        identity,
        isNot(const GitIdentity(
          label: 'Home',
          name: 'Jane Doe',
          email: 'jane@work.test',
        )),
      );
      expect(identity.props, ['Work', 'Jane Doe', 'jane@work.test']);
    });
  });
}
