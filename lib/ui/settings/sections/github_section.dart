import 'package:flutter/material.dart';
import '../../theme/app_palette.dart';

class GitHubSection extends StatelessWidget {
  const GitHubSection({super.key});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Center(child: Text('GitHub — content in 3B', style: TextStyle(color: p.fg2)));
  }
}
