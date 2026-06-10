import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gitopen/application/active_workspace_provider.dart';
import 'package:gitopen/application/main_view_provider.dart';
import 'package:gitopen/application/providers.dart';
import 'package:gitopen/application/scroll_request_provider.dart';
import 'package:gitopen/domain/commits/commit_sha.dart';
import 'package:gitopen/domain/refs/branch.dart';
import 'package:gitopen/domain/refs/remote.dart';
import 'package:gitopen/domain/refs/stash.dart';
import 'package:gitopen/domain/refs/submodule.dart';
import 'package:gitopen/domain/refs/tag.dart';
import 'package:gitopen/domain/refs/worktree.dart';
import 'package:gitopen/domain/repositories/repo_location.dart';

/// Selects [sha] in the graph and asks the graph panel to scroll it into
/// view. Also switches the main view back to the graph if the user is
/// currently looking at the working-copy changes.
void revealCommit(WidgetRef ref, CommitSha sha) {
  ref.read(mainViewProvider.notifier).state = MainView.graph;
  ref.read(selectedCommitShaProvider.notifier).state = sha;
  ref.read(scrollRequestProvider.notifier).state = sha;
}

/// Everything the sidebar renders for one repository, loaded in one shot so
/// the panel appears atomically.
class SidebarData {
  SidebarData(
    this.branches,
    this.tags,
    this.remotes,
    this.stashes,
    this.submodules,
    this.worktrees,
  );
  final List<Branch> branches;
  final List<Tag> tags;
  final List<Remote> remotes;
  final List<Stash> stashes;
  final List<Submodule> submodules;
  final List<Worktree> worktrees;
}

final FutureProviderFamily<SidebarData, RepoLocation> sidebarDataProvider =
    FutureProvider.family<SidebarData, RepoLocation>((ref, repo) async {
  final logger = ref.read(loggerProvider);
  final git = ref.watch(gitReadOperationsProvider);
  logger.i('sidebar: loading all sections for ${repo.displayName}');
  // All six loads are independent — run them concurrently; the panel still
  // appears atomically once the slowest completes.
  final (branches, tags, remotes, stashes, submodules, worktrees) = await (
    ref.watch(branchesProvider(repo).future),
    git.getTags(repo),
    git.getRemotes(repo),
    git.getStashes(repo),
    git.getSubmodules(repo),
    git.getWorktrees(repo),
  ).wait;
  logger.i('sidebar: ${branches.length} branches, ${tags.length} tags, '
      '${remotes.length} remotes, ${stashes.length} stashes, '
      '${submodules.length} submodules, ${worktrees.length} worktrees');
  return SidebarData(branches, tags, remotes, stashes, submodules, worktrees);
});
