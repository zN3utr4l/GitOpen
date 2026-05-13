import 'package:flutter/material.dart';
import '../theme/app_palette.dart';

enum CheckoutAction { discard, stash, keep }

/// Shown before a checkout when the working tree is dirty. Asks the user
/// what to do with the pending changes: discard, stash, or keep (attempt
/// checkout as-is; git will refuse if files would be overwritten).
class CheckoutChangesDialog extends StatelessWidget {
  final String targetRef;
  const CheckoutChangesDialog({super.key, required this.targetRef});

  static Future<CheckoutAction?> show(
      BuildContext context, String targetRef) async {
    return showDialog<CheckoutAction>(
      context: context,
      builder: (_) => CheckoutChangesDialog(targetRef: targetRef),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return AlertDialog(
      title: Text('Switch to "$targetRef"'),
      content: Text(
        'You have uncommitted changes. What would you like to do with them?',
        style: TextStyle(color: palette.fg1),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: palette.accentErr),
          onPressed: () => Navigator.pop(context, CheckoutAction.discard),
          child: const Text('Discard'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, CheckoutAction.stash),
          child: const Text('Stash'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, CheckoutAction.keep),
          child: const Text('Keep & switch'),
        ),
      ],
    );
  }
}
