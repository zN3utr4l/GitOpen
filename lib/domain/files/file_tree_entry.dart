import 'package:equatable/equatable.dart';

import 'package:gitopen/domain/commits/commit_sha.dart';

enum FileTreeKind { blob, tree, submodule, symlink }

final class FileTreeEntry extends Equatable {

  const FileTreeEntry({
    required this.name,
    required this.fullPath,
    required this.kind,
    this.sizeBytes,
    this.containingCommit,
  });
  final String name;
  final String fullPath;
  final FileTreeKind kind;
  final int? sizeBytes;
  final CommitSha? containingCommit;

  @override
  List<Object?> get props =>
      [name, fullPath, kind, sizeBytes, containingCommit];
}
