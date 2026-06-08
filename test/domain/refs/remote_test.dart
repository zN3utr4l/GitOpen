import 'package:flutter_test/flutter_test.dart';
import 'package:gitopen/domain/refs/branch.dart';
import 'package:gitopen/domain/refs/remote.dart';

void main() {
  group('Remote', () {
    const branch = Branch(
      name: 'main',
      fullName: 'refs/remotes/origin/main',
      isRemote: true,
      isCurrent: false,
      ahead: 0,
      behind: 0,
    );

    Remote build({
      String name = 'origin',
      String url = 'https://example.com/repo.git',
      List<Branch> branches = const [branch],
    }) {
      return Remote(name: name, url: url, branches: branches);
    }

    test('assigns all fields from constructor', () {
      final remote = build();
      expect(remote.name, 'origin');
      expect(remote.url, 'https://example.com/repo.git');
      expect(remote.branches, [branch]);
    });

    test('is equal when all fields match', () {
      expect(build(), build());
      expect(build().hashCode, build().hashCode);
    });

    test('differs by name', () {
      expect(build(), isNot(build(name: 'upstream')));
    });

    test('differs by url', () {
      expect(build(url: 'a'), isNot(build(url: 'b')));
    });

    test('differs by branches', () {
      expect(build(), isNot(build(branches: const [])));
    });
  });
}
