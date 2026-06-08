import 'package:gitopen/domain/commits/commit_sha.dart';
import 'package:gitopen/domain/repositories/repo_location.dart';

final class Workspace {

  Workspace(this.location, {
    this.selectedBranchFullName,
    this.selectedSha,
    this.scrollOffset = 0,
  });
  final RepoLocation location;
  String? selectedBranchFullName;
  CommitSha? selectedSha;
  int scrollOffset;
}
