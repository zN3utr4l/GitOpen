import 'package:flutter/material.dart';
import '../../theme/app_palette.dart';

class UpdatesSection extends StatelessWidget {
  const UpdatesSection({super.key});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Center(child: Text('Updates — content in 3E', style: TextStyle(color: p.fg2)));
  }
}
