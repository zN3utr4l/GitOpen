import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/active_workspace_provider.dart';
import '../../application/git/git_write_operations.dart';
import '../../application/operations/running_operation.dart';
import '../../application/providers.dart';
import '../../domain/repositories/repo_location.dart';

/// Three-button toolbar for Fetch / Pull / Push.
///
/// Buttons are disabled when no workspace is active. Each operation is
/// tracked through [operationsProvider] so the toast overlay and activity
/// panel reflect progress in real time.
class GitToolbar extends ConsumerWidget {
  const GitToolbar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeId = ref.watch(activeWorkspaceIdProvider);
    final workspaces = ref.watch(workspaceManagerProvider);
    final active =
        workspaces.where((w) => w.location.id == activeId).cast<dynamic>().firstOrNull;
    final enabled = active != null;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ToolbarButton(
          icon: Icons.cloud_download_outlined,
          label: 'Fetch',
          enabled: enabled,
          onTap: () => _fetch(ref, active!.location as RepoLocation),
        ),
        _ToolbarButton(
          icon: Icons.south,
          label: 'Pull',
          enabled: enabled,
          onTap: () => _pull(ref, active!.location as RepoLocation),
        ),
        _ToolbarButton(
          icon: Icons.north,
          label: 'Push',
          enabled: enabled,
          onTap: () => _push(ref, active!.location as RepoLocation),
        ),
      ],
    );
  }

  Future<void> _fetch(WidgetRef ref, RepoLocation repo) => _runStream(
        ref,
        OpKind.fetch,
        'Fetching origin',
        repo,
        ref.read(gitWriteOperationsProvider).fetch(repo),
      );

  Future<void> _pull(WidgetRef ref, RepoLocation repo) => _runStream(
        ref,
        OpKind.pull,
        'Pulling',
        repo,
        ref.read(gitWriteOperationsProvider).pull(repo, PullStrategy.merge),
      );

  Future<void> _push(WidgetRef ref, RepoLocation repo) => _runStream(
        ref,
        OpKind.push,
        'Pushing',
        repo,
        ref.read(gitWriteOperationsProvider).push(repo),
      );

  Future<void> _runStream(
    WidgetRef ref,
    OpKind kind,
    String label,
    RepoLocation repo,
    Stream<dynamic> stream,
  ) async {
    final ops = ref.read(operationsProvider.notifier);
    final id = ops.start(kind, label, repo: repo);
    try {
      await for (final ev in stream) {
        ops.updateProgress(id, (ev as dynamic).fraction as double?, (ev as dynamic).phase as String);
      }
      ops.finishSuccess(id);
      ref.invalidate(gitReadOperationsProvider);
    } catch (e) {
      ops.finishFailure(id, e.toString());
    }
  }
}

class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  const _ToolbarButton({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.4,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: const Color(0xFFB8B8BC)),
              const SizedBox(width: 5),
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFFD4D4D4),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
