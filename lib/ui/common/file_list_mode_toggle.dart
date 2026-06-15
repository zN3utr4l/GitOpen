import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gitopen/application/providers.dart';
import 'package:gitopen/ui/common/app_icon_button.dart';

/// Flat/tree toggle for file lists, backed by the persisted
/// `fileListsAsTree` setting (shared by the working-copy list and the
/// commit file list).
class FileListModeToggle extends ConsumerWidget {
  const FileListModeToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asTree = ref.watch(
      appSettingsProvider.select((s) => s.fileListsAsTree),
    );
    return AppIconButton(
      icon: Icons.account_tree_outlined,
      tooltip: asTree
          ? 'Tree view - click for a flat list'
          : 'Flat list - click for a tree view',
      selected: asTree,
      onPressed: () =>
          ref.read(appSettingsProvider.notifier).setFileListsAsTree(!asTree),
    );
  }
}
