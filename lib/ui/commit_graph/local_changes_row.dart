import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gitopen/application/active_workspace_provider.dart';
import 'package:gitopen/application/providers.dart';
import 'package:gitopen/domain/repositories/repo_location.dart';
import 'package:gitopen/ui/common/app_animated_row.dart';
import 'package:gitopen/ui/theme/app_design_tokens.dart';
import 'package:gitopen/ui/theme/app_palette.dart';

/// Pseudo-row pinned above the commit list. Selecting it shows the working
/// copy inline in the bottom panel (staging + commit), keeping the graph in
/// view — rather than navigating away to the full-screen Changes view.
class LocalChangesRow extends ConsumerWidget {
  const LocalChangesRow({required this.repo, super.key});
  final RepoLocation repo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(repoStatusProvider(repo));
    return async.when(
      // Keep the row visible during background reloads (auto-refresh).
      skipLoadingOnReload: true,
      data: (status) {
        if (status.entries.isEmpty) return const SizedBox.shrink();
        final count = status.entries.length;
        final palette = AppPalette.of(context);
        final typography = AppTypography.of(context);
        final selected = ref.watch(localChangesSelectedProvider) &&
            ref.watch(selectedCommitShaProvider) == null;
        // Mirror CommitRow: white ink on the bgAccent fill when selected.
        final fg = selected ? Colors.white : palette.accentTag;
        return AppAnimatedRow(
          selected: selected,
          height: 26,
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.of(context).md),
          semanticLabel: 'Local changes, $count file${count == 1 ? '' : 's'}',
          onTap: () {
            ref.read(localChangesSelectedProvider.notifier).state = true;
            ref.read(selectedCommitShaProvider.notifier).state = null;
          },
          child: Row(
            children: [
              Icon(Icons.edit_note, size: 16, color: fg),
              const SizedBox(width: 8),
              Text(
                'Local Changes ($count)',
                style: typography.bodyStrong.copyWith(color: fg),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (e, _) => const SizedBox.shrink(),
    );
  }
}
