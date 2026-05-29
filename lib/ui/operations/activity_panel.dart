import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/operations/running_operation.dart';
import '../../application/providers.dart';
import '../theme/app_palette.dart';

class ActivityPanel extends ConsumerWidget {
  const ActivityPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ops = ref.watch(operationsProvider);
    final palette = AppPalette.of(context);
    return Dialog(
      backgroundColor: palette.bg1,
      child: SizedBox(
        width: 560,
        height: 600,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Text('Activity', style: TextStyle(color: palette.fg0, fontSize: 14, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  TextButton(
                    onPressed: () => ref.read(operationsProvider.notifier).clearCompleted(),
                    child: const Text('Clear completed'),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, size: 16, color: palette.fg1),
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: palette.border),
            Expanded(
              child: ops.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.history,
                              size: 32, color: palette.fg3),
                          const SizedBox(height: 8),
                          Text('No recent activity',
                              style: TextStyle(
                                  color: palette.fg2, fontSize: 13)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: ops.length,
                      itemBuilder: (_, i) => _Row(op: ops[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatefulWidget {
  final RunningOperation op;
  const _Row({required this.op});
  @override
  State<_Row> createState() => _RowState();
}

class _RowState extends State<_Row> {
  bool _expanded = false;
  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final op = widget.op;
    IconData icon; Color color;
    switch (op.status) {
      case OperationStatus.running:
      case OperationStatus.pending:
        icon = Icons.refresh; color = palette.accentRemote; break;
      case OperationStatus.success:
        icon = Icons.check_circle; color = palette.accentCurrent; break;
      case OperationStatus.failed:
        icon = Icons.error; color = palette.accentErr; break;
      case OperationStatus.cancelled:
        icon = Icons.block; color = palette.fg2; break;
    }
    return InkWell(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 8),
              Expanded(child: Text(op.label, style: TextStyle(color: palette.fg0, fontSize: 12.5))),
              Text(op.startedAt.toLocal().toString().substring(11, 19),
                  style: TextStyle(color: palette.fg3, fontSize: 11)),
            ]),
            if (_expanded && op.stderrTail.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 22),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: palette.bg2, borderRadius: BorderRadius.circular(4)),
                  child: Text(op.stderrTail.join('\n'),
                      style: TextStyle(color: palette.fg1, fontSize: 11, fontFamily: 'monospace')),
                ),
              ),
            if (_expanded && op.errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 22),
                child: Text(op.errorMessage!, style: TextStyle(color: palette.accentErr, fontSize: 11)),
              ),
          ],
        ),
      ),
    );
  }
}
