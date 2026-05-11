import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/git/git_read_operations.dart';
import '../../application/providers.dart';
import '../../domain/commits/commit_info.dart';
import '../../domain/commits/commit_sha.dart';
import '../../domain/repositories/repo_location.dart';

final _commitInfoProvider = FutureProvider.family
    .autoDispose<CommitInfo?, ({RepoLocation repo, CommitSha sha})>((ref, key) async {
  final git = ref.watch(gitReadOperationsProvider);
  final commits = await git
      .getCommits(key.repo, CommitQuery(refSpec: key.sha.value, take: 1))
      .toList();
  return commits.isEmpty ? null : commits.first;
});

class CommitDetailsView extends ConsumerWidget {
  final RepoLocation repo;
  final CommitSha sha;
  const CommitDetailsView({super.key, required this.repo, required this.sha});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_commitInfoProvider((repo: repo, sha: sha)));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e',
          style: const TextStyle(color: Color(0xFFF48771)))),
      data: (c) => c == null
          ? const SizedBox.shrink()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _row('SHA', c.sha.value),
                  _row('AUTHOR', '${c.author.name} <${c.author.email}>  —  ${c.author.when.toLocal()}'),
                  _row('COMMITTER', '${c.committer.name} <${c.committer.email}>'),
                  _row('PARENTS', c.parentShas.map((p) => p.short()).join(', ')),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF25252A),
                      border: Border.all(color: const Color(0xFF313137)),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: SelectableText(
                      c.message,
                      style: const TextStyle(
                        color: Color(0xFFD4D4D4),
                        fontFamily: 'monospace',
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF888892),
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.4,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(color: Color(0xFFD4D4D4), fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }
}
