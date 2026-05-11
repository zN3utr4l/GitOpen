import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/active_workspace_provider.dart';
import '../../application/providers.dart';
import '../../domain/repositories/repo_id.dart';

class TabsBar extends ConsumerWidget {
  const TabsBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspaces = ref.watch(workspaceManagerProvider);
    final active = ref.watch(activeWorkspaceIdProvider);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final ws in workspaces)
            _TabItem(
              label: ws.location.displayName,
              isActive: ws.location.id == active,
              onActivate: () =>
                  ref.read(activeWorkspaceIdProvider.notifier).state =
                      ws.location.id,
              onClose: () => _close(ref, ws.location.id),
            ),
          _AddTabButton(onPressed: () => _openRepo(ref)),
        ],
      ),
    );
  }

  Future<void> _close(WidgetRef ref, RepoId id) async {
    final manager = ref.read(workspaceManagerProvider.notifier);
    await manager.close(id);
    final remaining = ref.read(workspaceManagerProvider);
    final active = ref.read(activeWorkspaceIdProvider);
    if (active == id) {
      ref.read(activeWorkspaceIdProvider.notifier).state =
          remaining.isNotEmpty ? remaining.first.location.id : null;
    }
  }

  Future<void> _openRepo(WidgetRef ref) async {
    final picker = ref.read(folderPickerProvider);
    final path = await picker.pickFolder('Open repository');
    if (path == null) return;
    final manager = ref.read(workspaceManagerProvider.notifier);
    final ws = await manager.open(path);
    ref.read(activeWorkspaceIdProvider.notifier).state = ws.location.id;
  }
}

class _TabItem extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onActivate;
  final VoidCallback onClose;
  const _TabItem({
    required this.label,
    required this.isActive,
    required this.onActivate,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isActive ? const Color(0xFF1F1F23) : Colors.transparent;
    final border = isActive ? const Color(0xFF404048) : Colors.transparent;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 1),
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(5),
          side: BorderSide(color: border, width: 1),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(5),
          onTap: onActivate,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 200, minHeight: 30),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isActive
                            ? const Color(0xFFD4D4D4)
                            : const Color(0xFFB8B8BC),
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: onClose,
                    borderRadius: BorderRadius.circular(3),
                    child: const Padding(
                      padding: EdgeInsets.all(2),
                      child: Icon(
                        Icons.close,
                        size: 14,
                        color: Color(0xFF888892),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AddTabButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _AddTabButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 1),
      child: Material(
        color: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(5),
          child: const SizedBox(
            width: 30,
            height: 30,
            child: Icon(Icons.add, size: 16, color: Color(0xFFB8B8BC)),
          ),
        ),
      ),
    );
  }
}
