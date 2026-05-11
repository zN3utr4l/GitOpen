import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/providers.dart';
import '../../domain/commits/commit_sha.dart';
import '../../domain/diff/diff_hunk.dart';
import '../../domain/diff/diff_line.dart';
import '../../domain/diff/diff_result.dart';
import '../../domain/diff/diff_spec.dart';
import '../../domain/diff/file_diff.dart';
import '../../domain/repositories/repo_location.dart';

final _diffProvider = FutureProvider.family
    .autoDispose<DiffResult, ({RepoLocation repo, CommitSha sha})>((ref, key) async {
  final git = ref.watch(gitReadOperationsProvider);
  return git.getDiff(key.repo, DiffSpecCommitVsParent(key.sha));
});

class DiffView extends ConsumerWidget {
  final RepoLocation repo;
  final CommitSha sha;
  const DiffView({super.key, required this.repo, required this.sha});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_diffProvider((repo: repo, sha: sha)));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e',
          style: const TextStyle(color: Color(0xFFF48771)))),
      data: (d) => ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: d.files.length,
        itemBuilder: (_, i) => _FileDiffBlock(file: d.files[i]),
      ),
    );
  }
}

class _FileDiffBlock extends StatelessWidget {
  final FileDiff file;
  const _FileDiffBlock({required this.file});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F23),
        border: Border.all(color: const Color(0xFF313137)),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(),
          if (file.isBinary)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('Binary file (no preview)',
                  style: TextStyle(color: Color(0xFF888892), fontStyle: FontStyle.italic)),
            )
          else
            for (final h in file.hunks) _hunk(h),
        ],
      ),
    );
  }

  Widget _header() {
    final pathLabel = file.oldPath != null && file.oldPath != file.path
        ? '${file.oldPath} → ${file.path}'
        : file.path;
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF2C2C31),
        border: Border(bottom: BorderSide(color: Color(0xFF313137))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          _KindBadge(kind: file.changeKind),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              pathLabel,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFFD4D4D4), fontSize: 12),
            ),
          ),
          Text(
            '+${file.linesAdded} -${file.linesDeleted}',
            style: const TextStyle(color: Color(0xFF888892), fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _hunk(DiffHunk h) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: const Color(0xFF25252A),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Text(h.header,
              style: const TextStyle(
                  color: Color(0xFF888892),
                  fontSize: 11.5,
                  fontStyle: FontStyle.italic,
                  fontFamily: 'monospace')),
        ),
        for (final line in h.lines) _DiffLineRow(line: line),
      ],
    );
  }
}

class _DiffLineRow extends StatelessWidget {
  final DiffLine line;
  const _DiffLineRow({required this.line});

  @override
  Widget build(BuildContext context) {
    Color bg;
    String prefix;
    switch (line.kind) {
      case DiffLineKind.addition:
        bg = const Color(0x1A4EC9B0); prefix = '+'; break;
      case DiffLineKind.deletion:
        bg = const Color(0x1FF48771); prefix = '-'; break;
      case DiffLineKind.context:
        bg = Colors.transparent; prefix = ' '; break;
    }
    return Container(
      color: bg,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 40, child: Text(line.oldLine?.toString() ?? '',
              textAlign: TextAlign.right,
              style: const TextStyle(color: Color(0xFF5D5D65), fontSize: 11, fontFamily: 'monospace'))),
          const SizedBox(width: 6),
          SizedBox(width: 40, child: Text(line.newLine?.toString() ?? '',
              textAlign: TextAlign.right,
              style: const TextStyle(color: Color(0xFF5D5D65), fontSize: 11, fontFamily: 'monospace'))),
          const SizedBox(width: 6),
          SizedBox(width: 14, child: Text(prefix,
              style: const TextStyle(color: Color(0xFF5D5D65), fontSize: 12, fontFamily: 'monospace'))),
          Expanded(
            child: Text(
              line.content,
              style: const TextStyle(color: Color(0xFFD4D4D4), fontSize: 12, fontFamily: 'monospace'),
              softWrap: false,
              overflow: TextOverflow.clip,
            ),
          ),
        ],
      ),
    );
  }
}

class _KindBadge extends StatelessWidget {
  final dynamic kind;
  const _KindBadge({required this.kind});

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _palette(kind.toString());
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(3)),
      child: Text(
        kind.toString().split('.').last.toUpperCase(),
        style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.3),
      ),
    );
  }

  (Color, Color) _palette(String s) {
    if (s.contains('added'))    return (const Color(0x2E4EC9B0), const Color(0xFF4EC9B0));
    if (s.contains('deleted'))  return (const Color(0x2EF48771), const Color(0xFFF48771));
    if (s.contains('modified')) return (const Color(0x2ED7BA7D), const Color(0xFFD7BA7D));
    if (s.contains('renamed'))  return (const Color(0x2E569CD6), const Color(0xFF569CD6));
    return (const Color(0xFF34343A), const Color(0xFFB8B8BC));
  }
}
