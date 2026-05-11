import '../../domain/refs/branch.dart';

final class BranchTreeNode {
  final String name;
  final String fullPath;
  final Branch? branch;
  final List<BranchTreeNode> children;

  BranchTreeNode({required this.name, required this.fullPath, this.branch})
      : children = [];

  bool get isLeaf => branch != null && children.isEmpty;
}

class BranchTree {
  static List<BranchTreeNode> build(Iterable<Branch> branches) {
    final roots = <BranchTreeNode>[];
    final lookup = <String, BranchTreeNode>{};

    for (final b in branches) {
      final parts = b.name.split('/');
      BranchTreeNode? parent;
      var currentPath = '';
      for (var i = 0; i < parts.length; i++) {
        currentPath = i == 0 ? parts[0] : '$currentPath/${parts[i]}';
        final isLast = i == parts.length - 1;
        var node = lookup[currentPath];
        if (node == null) {
          node = BranchTreeNode(
            name: parts[i],
            fullPath: currentPath,
            branch: isLast ? b : null,
          );
          lookup[currentPath] = node;
          if (parent == null) {
            roots.add(node);
          } else {
            parent.children.add(node);
          }
        }
        parent = node;
      }
    }
    _sortRecursive(roots);
    return roots;
  }

  static void _sortRecursive(List<BranchTreeNode> nodes) {
    nodes.sort((a, b) {
      final aFolder = a.children.isNotEmpty;
      final bFolder = b.children.isNotEmpty;
      if (aFolder != bFolder) return aFolder ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    for (final n in nodes) {
      _sortRecursive(n.children);
    }
  }

  static Iterable<String> allFolderPaths(Iterable<BranchTreeNode> nodes) sync* {
    for (final n in nodes) {
      if (n.children.isNotEmpty) {
        yield n.fullPath;
        yield* allFolderPaths(n.children);
      }
    }
  }
}
