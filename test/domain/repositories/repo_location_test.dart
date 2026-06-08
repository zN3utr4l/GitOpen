import 'package:flutter_test/flutter_test.dart';
import 'package:gitopen/domain/repositories/repo_id.dart';
import 'package:gitopen/domain/repositories/repo_location.dart';

void main() {
  group('RepoLocation', () {
    RepoLocation build({
      String id = 'id-1',
      String path = r'C:\repos\demo',
      String displayName = 'demo',
    }) {
      return RepoLocation(RepoId(id), path, displayName);
    }

    test('assigns all fields from constructor', () {
      final loc = build();
      expect(loc.id, const RepoId('id-1'));
      expect(loc.path, r'C:\repos\demo');
      expect(loc.displayName, 'demo');
    });

    test('is equal when all fields match', () {
      expect(build(), build());
      expect(build().hashCode, build().hashCode);
    });

    test('differs by id', () {
      expect(build(), isNot(build(id: 'id-2')));
    });

    test('differs by path', () {
      expect(build(path: 'a'), isNot(build(path: 'b')));
    });

    test('differs by displayName', () {
      expect(build(displayName: 'a'), isNot(build(displayName: 'b')));
    });
  });
}
