import 'package:equatable/equatable.dart';

import 'package:gitopen/domain/commits/commit_sha.dart';

sealed class DiffSpec extends Equatable {
  const DiffSpec();
}

final class DiffSpecCommitVsParent extends DiffSpec {

  const DiffSpecCommitVsParent(this.commitSha);
  final CommitSha commitSha;

  @override
  List<Object?> get props => [commitSha];
}

final class DiffSpecCommitVsCommit extends DiffSpec {

  const DiffSpecCommitVsCommit(this.from, this.to);
  final CommitSha from;
  final CommitSha to;

  @override
  List<Object?> get props => [from, to];
}

final class DiffSpecIndexVsHead extends DiffSpec {
  const DiffSpecIndexVsHead();

  @override
  List<Object?> get props => const [];
}

final class DiffSpecWorkingTreeVsIndex extends DiffSpec {
  const DiffSpecWorkingTreeVsIndex();

  @override
  List<Object?> get props => const [];
}
