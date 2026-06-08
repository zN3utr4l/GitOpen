import 'package:equatable/equatable.dart';

import 'package:gitopen/domain/commits/commit_sha.dart';
import 'package:gitopen/domain/status/working_file_entry.dart';

final class RepoStatus extends Equatable {

  const RepoStatus({
    required this.isDetached,
    required this.isBare,
    required this.entries,
    this.currentBranch,
    this.headSha,
    this.ahead = 0,
    this.behind = 0,
  });
  final String? currentBranch;
  final CommitSha? headSha;
  final bool isDetached;
  final bool isBare;
  final List<WorkingFileEntry> entries;

  /// Ahead/behind of the current branch vs its upstream.  Parsed from the
  /// `# branch.ab +N -M` line in `git status --porcelain=v2 --branch`.
  /// Both default to 0 when the branch has no upstream.
  final int ahead;
  final int behind;

  @override
  List<Object?> get props =>
      [currentBranch, headSha, isDetached, isBare, entries, ahead, behind];
}
