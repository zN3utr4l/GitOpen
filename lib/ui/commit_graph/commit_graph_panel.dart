import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/active_workspace_provider.dart';
import '../../application/commit_graph/commit_node.dart';
import '../../application/git/git_read_operations.dart';
import '../../application/providers.dart';
import '../../domain/commits/commit_info.dart';
import '../../domain/repositories/repo_location.dart';
import 'commit_row.dart';
import 'ref_decoration.dart';

class _GraphData {
  final List<CommitNode> nodes;
  final Map<String, List<RefDecoration>> refsBySha;
  final int maxLane;
  _GraphData(this.nodes, this.refsBySha, this.maxLane);
}

final commitGraphDataProvider =
    FutureProvider.family<_GraphData, RepoLocation>((ref, repo) async {
  final git = ref.watch(gitReadOperationsProvider);
  final layout = ref.watch(commitGraphLayoutProvider);

  final commits = <CommitInfo>[];
  await for (final c in git.getCommits(repo, const CommitQuery(take: 5000))) {
    commits.add(c);
  }
  final nodes = layout.compute(commits);

  // Load refs and index by sha
  final refsBySha = <String, List<RefDecoration>>{};
  final branches = await git.getBranches(repo);
  for (final b in branches) {
    final tip = b.tipSha;
    if (tip == null) continue;
    (refsBySha[tip.value] ??= []).add(RefDecoration(
      name: b.name,
      isRemote: b.isRemote,
      isTag: false,
      isCurrent: b.isCurrent,
    ));
  }
  final tags = await git.getTags(repo);
  for (final t in tags) {
    (refsBySha[t.targetSha.value] ??= []).add(RefDecoration(
      name: t.name,
      isRemote: false,
      isTag: true,
      isCurrent: false,
    ));
  }

  var maxLane = 0;
  for (final n in nodes) {
    if (n.lane > maxLane) maxLane = n.lane;
    for (final s in n.topSegments) {
      if (s.fromLane > maxLane) maxLane = s.fromLane;
      if (s.toLane > maxLane) maxLane = s.toLane;
    }
    for (final s in n.bottomSegments) {
      if (s.fromLane > maxLane) maxLane = s.fromLane;
      if (s.toLane > maxLane) maxLane = s.toLane;
    }
  }
  return _GraphData(nodes, refsBySha, maxLane);
});

class CommitGraphPanel extends ConsumerWidget {
  final RepoLocation repo;
  const CommitGraphPanel({super.key, required this.repo});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(commitGraphDataProvider(repo));
    return Container(
      color: const Color(0xFF1F1F23),
      child: async.when(
        data: (data) {
          if (data.nodes.isEmpty) {
            return const Center(
              child: Text('No commits in this repository.',
                  style: TextStyle(color: Color(0xFF888892))),
            );
          }
          final selected = ref.watch(selectedCommitShaProvider);
          return ListView.builder(
            itemExtent: 26,
            itemCount: data.nodes.length,
            itemBuilder: (context, i) {
              final node = data.nodes[i];
              final refs = data.refsBySha[node.commit.sha.value] ?? const [];
              return CommitRow(
                node: node,
                maxLane: data.maxLane,
                refs: refs,
                isSelected: selected == node.commit.sha,
                onTap: () => ref
                    .read(selectedCommitShaProvider.notifier)
                    .state = node.commit.sha,
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Failed to load graph: $e',
                style: const TextStyle(color: Color(0xFFF48771))),
          ),
        ),
      ),
    );
  }
}
