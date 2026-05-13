import '../../domain/commits/commit_sha.dart';

sealed class MergeOutcome {
  const MergeOutcome();
}

final class MergeFastForward extends MergeOutcome {
  final CommitSha newHead;
  const MergeFastForward(this.newHead);
}

final class MergeMerged extends MergeOutcome {
  final CommitSha mergeCommit;
  const MergeMerged(this.mergeCommit);
}

final class MergeConflict extends MergeOutcome {
  final List<String> conflictedPaths;
  const MergeConflict(this.conflictedPaths);
}

sealed class CherryPickOutcome {
  const CherryPickOutcome();
}

final class CherryPickApplied extends CherryPickOutcome {
  final CommitSha newCommit;
  const CherryPickApplied(this.newCommit);
}

final class CherryPickConflict extends CherryPickOutcome {
  final List<String> conflictedPaths;
  const CherryPickConflict(this.conflictedPaths);
}

sealed class RevertOutcome {
  const RevertOutcome();
}

final class RevertApplied extends RevertOutcome {
  final CommitSha newCommit;
  const RevertApplied(this.newCommit);
}

final class RevertConflict extends RevertOutcome {
  final List<String> conflictedPaths;
  const RevertConflict(this.conflictedPaths);
}
