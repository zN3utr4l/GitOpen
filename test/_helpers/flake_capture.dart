import 'dart:io';

/// Wraps a known-flaky real-git test [body]: when it throws, dumps the
/// fixture repo's git state — plus any [extraCommands] specific to the
/// assertion — to stderr before rethrowing. The two wrapped tests flake ONLY
/// under full-suite parallel load and the failure output has never been
/// captured; this makes every suite run a capture attempt (Phase 4 spec).
Future<void> withFlakeCapture(
  String repoPath,
  Future<void> Function() body, {
  List<List<String>> extraCommands = const [],
}) async {
  try {
    await body();
  } on Object catch (e) {
    stderr.writeln('=== FLAKE CAPTURED ($repoPath): $e');
    final commands = <List<String>>[
      ['log', '--oneline', '--all'],
      ['status', '--porcelain=v2'],
      ...extraCommands,
    ];
    for (final args in commands) {
      try {
        final r = await Process.run('git', args, workingDirectory: repoPath);
        stderr
          ..writeln('--- git ${args.join(' ')} (exit ${r.exitCode})')
          ..writeln(r.stdout)
          ..writeln(r.stderr);
      } on Object catch (runError) {
        stderr.writeln('--- git ${args.join(' ')} could not run: $runError');
      }
    }
    rethrow;
  }
}
