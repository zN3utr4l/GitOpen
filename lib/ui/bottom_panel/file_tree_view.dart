import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gitopen/application/providers.dart';
import 'package:gitopen/domain/commits/commit_sha.dart';
import 'package:gitopen/domain/files/file_tree_entry.dart';
import 'package:gitopen/domain/repositories/repo_location.dart';
import 'package:gitopen/ui/theme/app_palette.dart';

final AutoDisposeFutureProviderFamily<List<FileTreeEntry>,
        ({RepoLocation repo, CommitSha sha})> _fileTreeProvider =
    FutureProvider.family.autoDispose<List<FileTreeEntry>,
        ({RepoLocation repo, CommitSha sha})>((ref, key) async {
  final git = ref.watch(gitReadOperationsProvider);
  return git.getFileTree(key.repo, key.sha, '');
});

class FileTreeViewWidget extends ConsumerWidget {
  const FileTreeViewWidget({required this.repo, required this.sha, super.key});
  final RepoLocation repo;
  final CommitSha sha;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    final async = ref.watch(_fileTreeProvider((repo: repo, sha: sha)));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e',
          style: TextStyle(color: palette.accentErr))),
      data: (entries) {
        final sorted = [...entries]
          ..sort((a, b) {
            final aIsTree = a.kind == FileTreeKind.tree;
            final bIsTree = b.kind == FileTreeKind.tree;
            if (aIsTree != bIsTree) return aIsTree ? -1 : 1;
            return a.name.toLowerCase().compareTo(b.name.toLowerCase());
          });
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: sorted.length,
          itemBuilder: (_, i) {
            final e = sorted[i];
            final icon = e.kind == FileTreeKind.tree
                ? Icons.folder_outlined
                : e.kind == FileTreeKind.submodule
                    ? Icons.developer_board_outlined
                    : e.kind == FileTreeKind.symlink
                        ? Icons.link_outlined
                        : Icons.insert_drive_file_outlined;
            final iconColor = e.kind == FileTreeKind.tree
                ? palette.accentTag
                : palette.fg2;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 8),
              child: Row(
                children: [
                  Icon(icon, size: 15, color: iconColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      e.name,
                      style: TextStyle(
                        color: palette.fg0,
                        fontSize: 12.5,
                        fontWeight: e.kind == FileTreeKind.tree
                            ? FontWeight.w500
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                  if (e.sizeBytes != null)
                    Text('${e.sizeBytes}',
                        style: TextStyle(
                          color: palette.fg3,
                          fontSize: 11,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        )),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
