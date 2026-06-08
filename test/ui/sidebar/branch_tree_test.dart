import 'package:flutter_test/flutter_test.dart';
import 'package:gitopen/domain/commits/commit_sha.dart';
import 'package:gitopen/domain/refs/branch.dart';
import 'package:gitopen/ui/sidebar/branch_tree.dart';

Branch b(String name, {bool isCurrent = false, bool isRemote = false}) =>
    Branch(
      name: name,
      fullName: isRemote ? 'refs/remotes/$name' : 'refs/heads/$name',
      isRemote: isRemote,
      isCurrent: isCurrent,
      tipSha: CommitSha('aaaaaaaa'),
      ahead: 0,
      behind: 0,
    );

void main() {
  group('BranchTree.build', () {
    test('flat names produce flat roots', () {
      final tree = BranchTree.build([b('master'), b('main')]);
      expect(tree, hasLength(2));
      expect(tree.every((n) => n.isLeaf), isTrue);
    });

    test('slashed names produce nested folders', () {
      final tree = BranchTree.build([
        b('feature/auth'),
        b('feature/ui'),
        b('task/refactoring-opt'),
      ]);
      expect(tree, hasLength(2));
      final feature = tree.firstWhere((n) => n.name == 'feature');
      expect(feature.children, hasLength(2));
      expect(feature.isLeaf, isFalse);
      expect(feature.children.map((c) => c.name).toSet(), {'auth', 'ui'});
    });

    test('folders sort before leaves', () {
      final tree = BranchTree.build([
        b('master'),
        b('feature/auth'),
      ]);
      expect(tree.first.name, 'feature'); // folder first
      expect(tree.last.name, 'master');
    });
  });
}
