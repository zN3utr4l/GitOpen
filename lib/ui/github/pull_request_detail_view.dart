import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gitopen/application/github/github_models.dart';
import 'package:gitopen/domain/repositories/repo_location.dart';
import 'package:gitopen/ui/github/github_api_state.dart';
import 'package:gitopen/ui/github/github_providers.dart';
import 'package:gitopen/ui/github/pull_request_files_view.dart';
import 'package:gitopen/ui/theme/app_palette.dart';

class PullRequestDetailView extends ConsumerWidget {
  const PullRequestDetailView({
    required this.repo,
    required this.slug,
    required this.token,
    required this.number,
    super.key,
  });

  final RepoLocation repo;
  final RepoSlug slug;
  final String token;
  final int number;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (slug: slug, token: token, number: number);
    final detailAsync = ref.watch(githubPullRequestDetailProvider(key));
    return detailAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => GitHubApiErrorView(
        error: e,
        onRetry: () => ref.invalidate(githubPullRequestDetailProvider(key)),
      ),
      data: (detail) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PullRequestHeader(detail: detail),
          Expanded(
            child: PullRequestFilesView(
              slug: slug,
              token: token,
              number: number,
            ),
          ),
        ],
      ),
    );
  }
}

class _PullRequestHeader extends StatelessWidget {
  const _PullRequestHeader({required this.detail});

  final PullRequestDetail detail;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Container(
      decoration: BoxDecoration(
        color: palette.bg1,
        border: Border(bottom: BorderSide(color: palette.border)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'PR #${detail.number}',
                style: TextStyle(
                  color: palette.accentRemote,
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 8),
              _StateChip(detail: detail),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  detail.title,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.fg0,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${detail.baseRef} <- ${detail.headRef}',
            style: TextStyle(color: palette.fg2, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Text(
            detail.body.isEmpty ? 'No description' : detail.body,
            maxLines: 5,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: palette.fg1, fontSize: 12.5, height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _StateChip extends StatelessWidget {
  const _StateChip({required this.detail});

  final PullRequestDetail detail;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final label = detail.isDraft ? 'DRAFT' : detail.state.toUpperCase();
    final color = detail.isDraft
        ? palette.fg2
        : detail.isOpen
        ? palette.accentCurrent
        : palette.fg3;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
