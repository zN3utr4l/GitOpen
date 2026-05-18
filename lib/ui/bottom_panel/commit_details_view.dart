import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/git/git_read_operations.dart';
import '../../application/providers.dart';
import '../../domain/commits/commit_info.dart';
import '../../domain/commits/commit_sha.dart';
import '../../domain/repositories/repo_location.dart';
import '../theme/app_palette.dart';

/// Headline metadata for the details panel — author/committer/parents.
final _commitInfoProvider = FutureProvider.family
    .autoDispose<CommitInfo?, ({RepoLocation repo, CommitSha sha})>((ref, key) async {
  final git = ref.watch(gitReadOperationsProvider);
  final commits = await git
      .getCommits(key.repo, CommitQuery(refSpec: key.sha.value, take: 1))
      .toList();
  return commits.isEmpty ? null : commits.first;
});

/// Full commit body, fetched separately so the bulk graph load doesn't pay
/// for it.  Cached per (repo, sha) and disposed when the details view
/// stops watching this commit.
final _commitFullMessageProvider = FutureProvider.family
    .autoDispose<String?, ({RepoLocation repo, CommitSha sha})>((ref, key) {
  return ref
      .watch(gitReadOperationsProvider)
      .getCommitFullMessage(key.repo, key.sha);
});

class CommitDetailsView extends ConsumerWidget {
  final RepoLocation repo;
  final CommitSha sha;
  const CommitDetailsView({super.key, required this.repo, required this.sha});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    final key = (repo: repo, sha: sha);
    final async = ref.watch(_commitInfoProvider(key));
    final messageAsync = ref.watch(_commitFullMessageProvider(key));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e',
          style: TextStyle(color: palette.accentErr))),
      data: (c) => c == null
          ? const SizedBox.shrink()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _row(context, 'SHA', c.sha.value),
                  _row(context, 'AUTHOR', '${c.author.name} <${c.author.email}>  —  ${c.author.when.toLocal()}'),
                  _row(context, 'COMMITTER', '${c.committer.name} <${c.committer.email}>'),
                  _row(context, 'PARENTS', c.parentShas.map((p) => p.short()).join(', ')),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: palette.bg2,
                      border: Border.all(color: palette.border),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: SelectableText(
                      messageAsync.valueOrNull ?? c.summary,
                      style: TextStyle(
                        color: palette.fg0,
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

  Widget _row(BuildContext context, String label, String value) {
    final palette = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: TextStyle(
                color: palette.fg2,
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.4,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: TextStyle(color: palette.fg0, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }
}
