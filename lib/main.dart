import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  runApp(const ProviderScope(child: GitOpenApp()));

  doWhenWindowReady(() {
    const initialSize = Size(1400, 900);
    appWindow.minSize = const Size(800, 500);
    appWindow.size = initialSize;
    appWindow.alignment = Alignment.center;
    appWindow.title = 'GitOpen';
    appWindow.show();
  });
}

class GitOpenApp extends StatelessWidget {
  const GitOpenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GitOpen',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: const Color(0xFF1F1F23),
      ),
      home: const Shell(),
    );
  }
}

class Shell extends StatelessWidget {
  const Shell({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1F1F23),
      body: WindowBorder(
        color: const Color(0xFF2C2C31),
        width: 1,
        child: Column(
          children: [
            const _TitleBar(),
            Expanded(
              child: Center(
                child: Text(
                  'GitOpen — Phase F (chromeless shell)',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: const Color(0xFFB8B8BC),
                      ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TitleBar extends StatelessWidget {
  const _TitleBar();

  @override
  Widget build(BuildContext context) {
    return WindowTitleBarBox(
      child: Container(
        color: const Color(0xFF2C2C31),
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Color(0xFF4EC9B0),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'GitOpen',
                    style: TextStyle(
                      color: Color(0xFFD4D4D4),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: MoveWindow()),
            const _WindowControls(),
          ],
        ),
      ),
    );
  }
}

class _WindowControls extends StatelessWidget {
  const _WindowControls();

  @override
  Widget build(BuildContext context) {
    final colors = WindowButtonColors(
      iconNormal: const Color(0xFFB8B8BC),
      mouseOver: const Color(0xFF34343A),
      mouseDown: const Color(0xFF3D3D44),
      iconMouseOver: const Color(0xFFD4D4D4),
      iconMouseDown: const Color(0xFFD4D4D4),
    );
    final closeColors = WindowButtonColors(
      iconNormal: const Color(0xFFB8B8BC),
      mouseOver: const Color(0xFFC4314B),
      mouseDown: const Color(0xFFA52739),
      iconMouseOver: Colors.white,
      iconMouseDown: Colors.white,
    );
    return Row(children: [
      MinimizeWindowButton(colors: colors),
      MaximizeWindowButton(colors: colors),
      CloseWindowButton(colors: closeColors),
    ]);
  }
}
