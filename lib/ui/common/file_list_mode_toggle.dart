import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gitopen/application/providers.dart';
import 'package:gitopen/ui/theme/app_palette.dart';

/// Flat/tree toggle for file lists, backed by the persisted
/// `fileListsAsTree` setting (shared by the working-copy list and the
/// commit file list).
class FileListModeToggle extends ConsumerWidget {
  const FileListModeToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    final asTree = ref.watch(
      appSettingsProvider.select((s) => s.fileListsAsTree),
    );
    return Tooltip(
      message: asTree
          ? 'Tree view - click for a flat list'
          : 'Flat list - click for a tree view',
      waitDuration: const Duration(milliseconds: 500),
      child: InkWell(
        borderRadius: BorderRadius.circular(3),
        onTap: () =>
            ref.read(appSettingsProvider.notifier).setFileListsAsTree(!asTree),
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: Icon(
            Icons.account_tree_outlined,
            size: 14,
            color: asTree ? palette.accentCurrent : palette.fg3,
          ),
        ),
      ),
    );
  }
}
