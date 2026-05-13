import 'package:flutter/material.dart';
import '../../theme/app_palette.dart';

class AuthenticationSection extends StatelessWidget {
  const AuthenticationSection({super.key});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Center(child: Text('Authentication — content in 3B', style: TextStyle(color: p.fg2)));
  }
}
