import 'package:equatable/equatable.dart';

import 'package:gitopen/domain/commits/commit_sha.dart';

final class Stash extends Equatable {

  const Stash({
    required this.index,
    required this.sha,
    required this.message,
    required this.createdAt,
  });
  final int index;
  final CommitSha sha;
  final String message;
  final DateTime createdAt;

  @override
  List<Object?> get props => [index, sha, message, createdAt];
}
