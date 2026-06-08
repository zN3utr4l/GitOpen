import 'package:equatable/equatable.dart';

import 'package:gitopen/domain/commits/commit_sha.dart';

final class Tag extends Equatable {

  const Tag({
    required this.name,
    required this.fullName,
    required this.targetSha,
    required this.isAnnotated,
  });
  final String name;
  final String fullName;
  final CommitSha targetSha;
  final bool isAnnotated;

  @override
  List<Object?> get props => [name, fullName, targetSha, isAnnotated];
}
