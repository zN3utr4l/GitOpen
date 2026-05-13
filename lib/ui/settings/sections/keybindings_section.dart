import 'package:flutter/material.dart';
import '../../theme/app_palette.dart';

class KeybindingsSection extends StatelessWidget {
  const KeybindingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Center(child: Text('Keybindings — content in 3C', style: TextStyle(color: p.fg2)));
  }
}
