import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/active_workspace_provider.dart';
import '../../domain/commits/commit_sha.dart';
import '../../domain/repositories/repo_location.dart';
import 'commit_details_view.dart';
import 'diff_view.dart';
import 'file_tree_view.dart';

class BottomPanel extends ConsumerStatefulWidget {
  final RepoLocation repo;
  const BottomPanel({super.key, required this.repo});

  @override
  ConsumerState<BottomPanel> createState() => _BottomPanelState();
}

class _BottomPanelState extends ConsumerState<BottomPanel> {
  String _tab = 'commit';

  @override
  Widget build(BuildContext context) {
    final sha = ref.watch(selectedCommitShaProvider);
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1F1F23),
        border: Border(top: BorderSide(color: Color(0xFF313137))),
      ),
      child: Column(
        children: [
          _TabsBar(active: _tab, onSelect: (v) => setState(() => _tab = v)),
          Expanded(child: _body(sha)),
        ],
      ),
    );
  }

  Widget _body(CommitSha? sha) {
    if (sha == null) {
      return const Center(
        child: Text('Select a commit.',
            style: TextStyle(color: Color(0xFF888892), fontStyle: FontStyle.italic)),
      );
    }
    switch (_tab) {
      case 'commit':
        return CommitDetailsView(repo: widget.repo, sha: sha);
      case 'changes':
        return DiffView(repo: widget.repo, sha: sha);
      case 'files':
        return FileTreeViewWidget(repo: widget.repo, sha: sha);
    }
    return const SizedBox.shrink();
  }
}

class _TabsBar extends StatelessWidget {
  final String active;
  final ValueChanged<String> onSelect;
  const _TabsBar({required this.active, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF2C2C31),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          _Tab(label: 'Commit',    value: 'commit',  active: active, onSelect: onSelect),
          _Tab(label: 'Changes',   value: 'changes', active: active, onSelect: onSelect),
          _Tab(label: 'File Tree', value: 'files',   active: active, onSelect: onSelect),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final String value;
  final String active;
  final ValueChanged<String> onSelect;
  const _Tab({
    required this.label,
    required this.value,
    required this.active,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = active == value;
    return InkWell(
      onTap: () => onSelect(value),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isActive ? const Color(0xFF4EC9B0) : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            label,
            style: TextStyle(
              color: isActive ? const Color(0xFFD4D4D4) : const Color(0xFFB8B8BC),
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}
