import 'package:flutter/material.dart';
import '../../theme/app_palette.dart';

class AboutSection extends StatelessWidget {
  const AboutSection({super.key});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('GitOpen', style: TextStyle(color: p.fg0, fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text('Version 0.3.0-dev', style: TextStyle(color: p.fg2, fontSize: 12)),
        const SizedBox(height: 16),
        Text('Cross-platform desktop git client.', style: TextStyle(color: p.fg1)),
        const SizedBox(height: 16),
        Text('License: MIT', style: TextStyle(color: p.fg2, fontSize: 12)),
      ]),
    );
  }
}
