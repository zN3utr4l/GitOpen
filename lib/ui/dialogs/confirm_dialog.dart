import 'package:flutter/material.dart';
import '../theme/app_palette.dart';

class ConfirmDialog extends StatelessWidget {
  final String title;
  final String body;
  final String? confirmLabel;
  final bool dangerous;
  const ConfirmDialog({super.key, required this.title, required this.body, this.confirmLabel, this.dangerous = false});

  static Future<bool> show(BuildContext context, {required String title, required String body, String? confirmLabel, bool dangerous = false}) async {
    final ok = await showDialog<bool>(context: context, builder: (_) => ConfirmDialog(title: title, body: body, confirmLabel: confirmLabel, dangerous: dangerous));
    return ok ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        ElevatedButton(
          style: dangerous ? ElevatedButton.styleFrom(backgroundColor: palette.accentErr) : null,
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel ?? 'OK'),
        ),
      ],
    );
  }
}
