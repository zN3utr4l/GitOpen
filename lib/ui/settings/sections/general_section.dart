import 'package:flutter/material.dart';
import '../../theme/app_palette.dart';

class GeneralSection extends StatelessWidget {
  const GeneralSection({super.key});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Center(child: Text('General — content in 3B', style: TextStyle(color: p.fg2)));
  }
}
