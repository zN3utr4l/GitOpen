import 'package:flutter_test/flutter_test.dart';
import 'package:gitopen/application/launcher/process_runner.dart';
import 'package:gitopen/application/launcher/repo_launcher.dart';
import 'package:gitopen/domain/repositories/repo_id.dart';
import 'package:gitopen/domain/repositories/repo_location.dart';
import 'package:gitopen/infrastructure/launcher/system_repo_launcher.dart';

class FakeProcessRunner implements ProcessRunner {
  FakeProcessRunner({
    this.probes = const {},
    this.failingExecutables = const {},
  });
  final Map<String, ProcessProbeResult> probes;
  final List<(String exe, List<String> args)> calls = [];
  /// Spawn fails when the executable matches OR when any token in `executable`
  /// + `args` matches. The arg-level check lets tests express "the Windows
  /// terminal chain wraps wt.exe in `cmd /c start ... wt.exe ...`, so fail
  /// the launch when wt.exe appears in args."
  final Set<String> failingExecutables;

  @override
  Future<ProcessProbeResult> probe(String command) async =>
      probes[command] ?? const ProcessProbeResult(false, null);

  @override
  Future<bool> startDetached(String executable, List<String> args) async {
    calls.add((executable, args));
    if (failingExecutables.contains(executable)) return false;
    for (final a in args) {
      if (failingExecutables.contains(a)) return false;
    }
    return true;
  }
}

class CountingRunner implements ProcessRunner {
  int probeCount = 0;
  @override
  Future<ProcessProbeResult> probe(String command) async {
    probeCount++;
    return const ProcessProbeResult(false, null);
  }

  @override
  Future<bool> startDetached(String executable, List<String> args) async =>
      true;
}

RepoLocation _repo(String path) =>
    RepoLocation(const RepoId('id'), path, 'repo');

void main() {
  group('EditorTarget', () {
    test('equality is by id', () {
      const a = EditorTarget(
          id: 'vscode', displayName: 'VS Code', executable: 'code');
      const b = EditorTarget(
          id: 'vscode',
          displayName: 'VS Code',
          executable: '/usr/local/bin/code');
      expect(a, equals(b));
    });

    test('toString shows displayName', () {
      const e = EditorTarget(
          id: 'cursor', displayName: 'Cursor', executable: 'cursor');
      expect(e.toString(), contains('Cursor'));
    });
  });

  group('SystemRepoLauncher.revealInFiles', () {
    test('uses platform-correct command (windows)', () async {
      final fake = FakeProcessRunner();
      final launcher =
          SystemRepoLauncher(runner: fake, platformOverride: 'windows');
      await launcher.revealInFiles(_repo(r'C:\repo'));
      expect(fake.calls.single.$1, 'explorer.exe');
      expect(fake.calls.single.$2, [r'C:\repo']);
    });

    test('throws LauncherException when spawn fails', () async {
      final fake = FakeProcessRunner(failingExecutables: {'explorer.exe'});
      final launcher =
          SystemRepoLauncher(runner: fake, platformOverride: 'windows');
      expect(
        () => launcher.revealInFiles(_repo(r'C:\repo')),
        throwsA(isA<LauncherException>()),
      );
    });

    test('macOS uses open', () async {
      final fake = FakeProcessRunner();
      final launcher =
          SystemRepoLauncher(runner: fake, platformOverride: 'macos');
      await launcher.revealInFiles(_repo('/repo'));
      expect(fake.calls.single.$1, 'open');
    });

    test('linux uses xdg-open', () async {
      final fake = FakeProcessRunner();
      final launcher =
          SystemRepoLauncher(runner: fake, platformOverride: 'linux');
      await launcher.revealInFiles(_repo('/repo'));
      expect(fake.calls.single.$1, 'xdg-open');
    });
  });

  group('SystemRepoLauncher.openInTerminal', () {
    // The Windows launcher wraps every candidate in `cmd /c start "" /D <path>
    // <exe> <args>` so console apps get a real console window. Tests check
    // both that the probe gate is honoured and that the wrapped command
    // carries the right inner executable.
    test('windows prefers wt.exe', () async {
      final fake = FakeProcessRunner(probes: {
        'wt.exe': const ProcessProbeResult(true, null),
      });
      final launcher =
          SystemRepoLauncher(runner: fake, platformOverride: 'windows');
      await launcher.openInTerminal(_repo(r'C:\repo'));
      expect(fake.calls.single.$1, 'cmd.exe');
      expect(fake.calls.single.$2,
          ['/c', 'start', '', '/D', r'C:\repo', 'wt.exe', '-d', r'C:\repo']);
    });

    test('windows falls back to powershell when wt.exe fails', () async {
      final fake = FakeProcessRunner(
        probes: {
          'wt.exe': const ProcessProbeResult(true, null),
          'powershell.exe': const ProcessProbeResult(true, null),
        },
        failingExecutables: {'wt.exe'},
      );
      final launcher =
          SystemRepoLauncher(runner: fake, platformOverride: 'windows');
      await launcher.openInTerminal(_repo(r'C:\repo'));
      expect(fake.calls.length, 2);
      expect(fake.calls.last.$2, contains('powershell.exe'));
    });

    test('windows falls back to cmd when wt and powershell fail', () async {
      final fake = FakeProcessRunner(
        probes: {
          'wt.exe': const ProcessProbeResult(true, null),
          'powershell.exe': const ProcessProbeResult(true, null),
          'cmd.exe': const ProcessProbeResult(true, null),
        },
        failingExecutables: {'wt.exe', 'powershell.exe'},
      );
      final launcher =
          SystemRepoLauncher(runner: fake, platformOverride: 'windows');
      await launcher.openInTerminal(_repo(r'C:\repo'));
      // The final, successful attempt wraps cmd.exe via the cmd shim too.
      expect(fake.calls.last.$2, contains('cmd.exe'));
    });

    test('throws when all fallbacks fail', () async {
      final fake = FakeProcessRunner(
        probes: {
          'wt.exe': const ProcessProbeResult(true, null),
          'pwsh.exe': const ProcessProbeResult(true, null),
          'powershell.exe': const ProcessProbeResult(true, null),
          'cmd.exe': const ProcessProbeResult(true, null),
        },
        failingExecutables: {
          'wt.exe',
          'pwsh.exe',
          'powershell.exe',
          'cmd.exe',
        },
      );
      final launcher =
          SystemRepoLauncher(runner: fake, platformOverride: 'windows');
      expect(
        () => launcher.openInTerminal(_repo(r'C:\repo')),
        throwsA(isA<LauncherException>()),
      );
    });

    test('macos uses open -a Terminal', () async {
      final fake = FakeProcessRunner();
      final launcher =
          SystemRepoLauncher(runner: fake, platformOverride: 'macos');
      await launcher.openInTerminal(_repo('/repo'));
      expect(fake.calls.single.$1, 'open');
      expect(fake.calls.single.$2, ['-a', 'Terminal', '/repo']);
    });

    test('linux tries gnome-terminal first', () async {
      final fake = FakeProcessRunner();
      final launcher =
          SystemRepoLauncher(runner: fake, platformOverride: 'linux');
      await launcher.openInTerminal(_repo('/repo'));
      expect(fake.calls.single.$1, 'gnome-terminal');
    });
  });

  group('SystemRepoLauncher.detectAvailableEditors', () {
    test('returns VS Code when `code` probe succeeds', () async {
      final fake = FakeProcessRunner(probes: {
        'code': const ProcessProbeResult(
            true, r'C:\Program Files\Microsoft VS Code\bin\code.cmd'),
      });
      final launcher =
          SystemRepoLauncher(runner: fake, platformOverride: 'windows');
      final editors = await launcher.detectAvailableEditors();
      expect(editors, hasLength(1));
      expect(editors.single.id, 'vscode');
      expect(editors.single.executable, contains('code'));
    });

    test('returns multiple editors when several probes succeed', () async {
      final fake = FakeProcessRunner(probes: {
        'code': const ProcessProbeResult(true, 'code'),
        'cursor': const ProcessProbeResult(true, 'cursor'),
        'rider64': const ProcessProbeResult(true, 'rider64'),
      });
      final launcher =
          SystemRepoLauncher(runner: fake, platformOverride: 'windows');
      final editors = await launcher.detectAvailableEditors();
      final ids = editors.map((e) => e.id).toSet();
      expect(ids, containsAll(['vscode', 'cursor', 'rider']));
    });

    test('returns empty list when no editor detected', () async {
      final fake = FakeProcessRunner();
      final launcher =
          SystemRepoLauncher(runner: fake, platformOverride: 'linux');
      expect(await launcher.detectAvailableEditors(), isEmpty);
    });

    test('result is cached across calls', () async {
      final counting = CountingRunner();
      final launcher =
          SystemRepoLauncher(runner: counting, platformOverride: 'linux');
      await launcher.detectAvailableEditors();
      final firstCount = counting.probeCount;
      await launcher.detectAvailableEditors();
      expect(counting.probeCount, firstCount,
          reason: 'second call must not re-probe');
    });
  });

  group('SystemRepoLauncher.openInEditor', () {
    test('starts editor executable with repo path', () async {
      final fake = FakeProcessRunner();
      final launcher =
          SystemRepoLauncher(runner: fake, platformOverride: 'windows');
      const editor = EditorTarget(
          id: 'vscode', displayName: 'VS Code', executable: 'code');
      await launcher.openInEditor(_repo(r'C:\repo'), editor);
      expect(fake.calls.single.$1, 'code');
      expect(fake.calls.single.$2, [r'C:\repo']);
    });

    test('throws LauncherException when spawn fails', () async {
      final fake = FakeProcessRunner(failingExecutables: {'code'});
      final launcher =
          SystemRepoLauncher(runner: fake, platformOverride: 'macos');
      const editor = EditorTarget(
          id: 'vscode', displayName: 'VS Code', executable: 'code');
      expect(
        () => launcher.openInEditor(_repo('/repo'), editor),
        throwsA(isA<LauncherException>()
            .having((e) => e.message, 'message', contains('VS Code'))),
      );
    });
  });
}
