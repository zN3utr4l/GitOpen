# Open Repo In… Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a toolbar dropdown "Open" that reveals the active repo in the system file manager, opens it in a terminal, and opens it in any detected editor (VS Code, Cursor, JetBrains IDEs, Sublime, Android Studio, Fleet).

**Architecture:** New `RepoLauncher` interface in `lib/application/launcher/`, system implementation in `lib/infrastructure/launcher/`. Editor detection probes the PATH once per session and is exposed via a `FutureProvider`. UI lives in a new `_OpenDropdown` inside `git_toolbar.dart`.

**Tech Stack:** Dart, Flutter, Riverpod, `dart:io` `Process` (no new deps).

**Spec:** `docs/superpowers/specs/2026-05-15-open-repo-in-design.md`

---

## File Structure

Files to create:
- `lib/application/launcher/repo_launcher.dart` — abstract interface, `EditorTarget`, `LauncherException`
- `lib/application/launcher/process_runner.dart` — injectable `ProcessRunner` (`run`/`start`) so unit tests can fake process behaviour
- `lib/infrastructure/launcher/system_process_runner.dart` — real `Process.run`/`Process.start` impl
- `lib/infrastructure/launcher/system_repo_launcher.dart` — `SystemRepoLauncher implements RepoLauncher`
- `test/application/launcher/repo_launcher_test.dart` — unit tests with a fake runner

Files to modify:
- `lib/application/providers.dart` — add `repoLauncherProvider`, `availableEditorsProvider`
- `lib/ui/toolbar/git_toolbar.dart` — add `_OpenDropdown`

---

## Task 1: Define `EditorTarget` value object

**Files:**
- Create: `lib/application/launcher/repo_launcher.dart`
- Test: `test/application/launcher/repo_launcher_test.dart`

- [ ] **Step 1: Write failing test**

```dart
// test/application/launcher/repo_launcher_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:gitopen/application/launcher/repo_launcher.dart';

void main() {
  group('EditorTarget', () {
    test('equality is by id', () {
      const a = EditorTarget(id: 'vscode', displayName: 'VS Code', executable: 'code');
      const b = EditorTarget(id: 'vscode', displayName: 'VS Code', executable: '/usr/local/bin/code');
      expect(a, equals(b));
    });

    test('toString shows displayName', () {
      const e = EditorTarget(id: 'cursor', displayName: 'Cursor', executable: 'cursor');
      expect(e.toString(), contains('Cursor'));
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/application/launcher/repo_launcher_test.dart`
Expected: FAIL — `repo_launcher.dart` does not exist.

- [ ] **Step 3: Create `repo_launcher.dart` with `EditorTarget`**

```dart
// lib/application/launcher/repo_launcher.dart
import '../../domain/repositories/repo_location.dart';

class EditorTarget {
  final String id;
  final String displayName;
  final String executable;

  const EditorTarget({
    required this.id,
    required this.displayName,
    required this.executable,
  });

  @override
  bool operator ==(Object other) => other is EditorTarget && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'EditorTarget($displayName)';
}

class LauncherException implements Exception {
  final String message;
  const LauncherException(this.message);
  @override
  String toString() => message;
}

abstract interface class RepoLauncher {
  Future<void> revealInFiles(RepoLocation repo);
  Future<void> openInTerminal(RepoLocation repo);
  Future<void> openInEditor(RepoLocation repo, EditorTarget editor);
  Future<List<EditorTarget>> detectAvailableEditors();
}
```

- [ ] **Step 4: Run test to verify pass**

Run: `flutter test test/application/launcher/repo_launcher_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/application/launcher/repo_launcher.dart test/application/launcher/repo_launcher_test.dart
git commit -m "feat(launcher): add RepoLauncher interface and EditorTarget"
```

---

## Task 2: Injectable `ProcessRunner`

**Files:**
- Create: `lib/application/launcher/process_runner.dart`
- Create: `lib/infrastructure/launcher/system_process_runner.dart`

Rationale: `SystemRepoLauncher` cannot be unit-tested if it calls `Process.start` directly. The runner abstracts spawn + which-style probe.

- [ ] **Step 1: Write the interface**

```dart
// lib/application/launcher/process_runner.dart
class ProcessProbeResult {
  final bool found;
  final String? resolvedPath;
  const ProcessProbeResult(this.found, this.resolvedPath);
}

abstract interface class ProcessRunner {
  /// Returns true if [command] resolves on PATH (`where` / `which`).
  Future<ProcessProbeResult> probe(String command);

  /// Starts [executable] with [args] detached. Returns true on successful spawn.
  /// Returns false ONLY if the executable could not be started (not on later exit).
  Future<bool> startDetached(String executable, List<String> args);
}
```

- [ ] **Step 2: Write the system impl**

```dart
// lib/infrastructure/launcher/system_process_runner.dart
import 'dart:io';

import '../../application/launcher/process_runner.dart';

class SystemProcessRunner implements ProcessRunner {
  @override
  Future<ProcessProbeResult> probe(String command) async {
    final probe = Platform.isWindows ? 'where' : 'which';
    try {
      final result = await Process.run(probe, [command], runInShell: false);
      if (result.exitCode != 0) return const ProcessProbeResult(false, null);
      final out = (result.stdout as String).trim();
      if (out.isEmpty) return const ProcessProbeResult(false, null);
      final firstLine = out.split(RegExp(r'\r?\n')).first.trim();
      return ProcessProbeResult(true, firstLine);
    } on ProcessException {
      return const ProcessProbeResult(false, null);
    }
  }

  @override
  Future<bool> startDetached(String executable, List<String> args) async {
    try {
      await Process.start(
        executable,
        args,
        mode: ProcessStartMode.detached,
        runInShell: Platform.isWindows,
      );
      return true;
    } on ProcessException {
      return false;
    }
  }
}
```

- [ ] **Step 3: Sanity build**

Run: `flutter analyze lib/application/launcher lib/infrastructure/launcher`
Expected: No issues.

- [ ] **Step 4: Commit**

```bash
git add lib/application/launcher/process_runner.dart lib/infrastructure/launcher/system_process_runner.dart
git commit -m "feat(launcher): add injectable ProcessRunner abstraction"
```

---

## Task 3: `SystemRepoLauncher.revealInFiles` (TDD)

**Files:**
- Create: `lib/infrastructure/launcher/system_repo_launcher.dart`
- Modify: `test/application/launcher/repo_launcher_test.dart`

- [ ] **Step 1: Add fake runner + test**

Append to `test/application/launcher/repo_launcher_test.dart`:

```dart
import 'package:gitopen/application/launcher/process_runner.dart';
import 'package:gitopen/domain/repositories/repo_id.dart';
import 'package:gitopen/domain/repositories/repo_location.dart';
import 'package:gitopen/infrastructure/launcher/system_repo_launcher.dart';

class FakeProcessRunner implements ProcessRunner {
  final Map<String, ProcessProbeResult> probes;
  final List<(String exe, List<String> args)> calls = [];
  final Set<String> failingExecutables;
  FakeProcessRunner({
    this.probes = const {},
    this.failingExecutables = const {},
  });

  @override
  Future<ProcessProbeResult> probe(String command) async =>
      probes[command] ?? const ProcessProbeResult(false, null);

  @override
  Future<bool> startDetached(String executable, List<String> args) async {
    calls.add((executable, args));
    return !failingExecutables.contains(executable);
  }
}

RepoLocation _repo(String path) =>
    RepoLocation(RepoId('id'), path, 'repo');

void _groupLauncher() {
  group('SystemRepoLauncher.revealInFiles', () {
    test('uses platform-correct command', () async {
      final fake = FakeProcessRunner();
      final launcher = SystemRepoLauncher(runner: fake, platformOverride: 'windows');
      await launcher.revealInFiles(_repo(r'C:\repo'));
      expect(fake.calls.single.$1, 'explorer.exe');
      expect(fake.calls.single.$2, [r'C:\repo']);
    });

    test('throws LauncherException when spawn fails', () async {
      final fake = FakeProcessRunner(failingExecutables: {'explorer.exe'});
      final launcher = SystemRepoLauncher(runner: fake, platformOverride: 'windows');
      expect(
        () => launcher.revealInFiles(_repo(r'C:\repo')),
        throwsA(isA<LauncherException>()),
      );
    });

    test('macOS uses open', () async {
      final fake = FakeProcessRunner();
      final launcher = SystemRepoLauncher(runner: fake, platformOverride: 'macos');
      await launcher.revealInFiles(_repo('/repo'));
      expect(fake.calls.single.$1, 'open');
    });

    test('linux uses xdg-open', () async {
      final fake = FakeProcessRunner();
      final launcher = SystemRepoLauncher(runner: fake, platformOverride: 'linux');
      await launcher.revealInFiles(_repo('/repo'));
      expect(fake.calls.single.$1, 'xdg-open');
    });
  });
}
```

Then add `_groupLauncher();` inside the existing `void main() { ... }` after the existing group.

- [ ] **Step 2: Run tests, expect FAIL (no SystemRepoLauncher yet)**

Run: `flutter test test/application/launcher/repo_launcher_test.dart`
Expected: FAIL — cannot resolve `SystemRepoLauncher`.

- [ ] **Step 3: Create the implementation skeleton + `revealInFiles`**

```dart
// lib/infrastructure/launcher/system_repo_launcher.dart
import 'dart:io';

import '../../application/launcher/process_runner.dart';
import '../../application/launcher/repo_launcher.dart';
import '../../domain/repositories/repo_location.dart';
import 'system_process_runner.dart';

class SystemRepoLauncher implements RepoLauncher {
  final ProcessRunner _runner;
  final String _platform; // 'windows' | 'macos' | 'linux'

  SystemRepoLauncher({
    ProcessRunner? runner,
    String? platformOverride,
  })  : _runner = runner ?? SystemProcessRunner(),
        _platform = platformOverride ?? _detectPlatform();

  static String _detectPlatform() {
    if (Platform.isWindows) return 'windows';
    if (Platform.isMacOS) return 'macos';
    return 'linux';
  }

  @override
  Future<void> revealInFiles(RepoLocation repo) async {
    final (exe, args) = switch (_platform) {
      'windows' => ('explorer.exe', [repo.path]),
      'macos' => ('open', [repo.path]),
      _ => ('xdg-open', [repo.path]),
    };
    final ok = await _runner.startDetached(exe, args);
    if (!ok) {
      throw LauncherException('Could not open file manager ($exe).');
    }
  }

  @override
  Future<void> openInTerminal(RepoLocation repo) async {
    throw UnimplementedError();
  }

  @override
  Future<void> openInEditor(RepoLocation repo, EditorTarget editor) async {
    throw UnimplementedError();
  }

  @override
  Future<List<EditorTarget>> detectAvailableEditors() async {
    throw UnimplementedError();
  }
}
```

- [ ] **Step 4: Run tests, expect PASS for the 4 revealInFiles tests**

Run: `flutter test test/application/launcher/repo_launcher_test.dart`
Expected: PASS (6 tests total — 2 prior + 4 new).

- [ ] **Step 5: Commit**

```bash
git add lib/infrastructure/launcher/system_repo_launcher.dart test/application/launcher/repo_launcher_test.dart
git commit -m "feat(launcher): implement revealInFiles per platform"
```

---

## Task 4: `openInTerminal` with fallback chains (TDD)

**Files:**
- Modify: `lib/infrastructure/launcher/system_repo_launcher.dart`
- Modify: `test/application/launcher/repo_launcher_test.dart`

- [ ] **Step 1: Add tests**

Append to `_groupLauncher()`:

```dart
group('SystemRepoLauncher.openInTerminal', () {
  test('windows prefers wt.exe', () async {
    final fake = FakeProcessRunner();
    final launcher = SystemRepoLauncher(runner: fake, platformOverride: 'windows');
    await launcher.openInTerminal(_repo(r'C:\repo'));
    expect(fake.calls.single.$1, 'wt.exe');
    expect(fake.calls.single.$2, ['-d', r'C:\repo']);
  });

  test('windows falls back to powershell when wt.exe fails', () async {
    final fake = FakeProcessRunner(failingExecutables: {'wt.exe'});
    final launcher = SystemRepoLauncher(runner: fake, platformOverride: 'windows');
    await launcher.openInTerminal(_repo(r'C:\repo'));
    expect(fake.calls.map((c) => c.$1).toList(), ['wt.exe', 'powershell']);
  });

  test('windows falls back to cmd when wt and powershell fail', () async {
    final fake = FakeProcessRunner(failingExecutables: {'wt.exe', 'powershell'});
    final launcher = SystemRepoLauncher(runner: fake, platformOverride: 'windows');
    await launcher.openInTerminal(_repo(r'C:\repo'));
    expect(fake.calls.last.$1, 'cmd');
  });

  test('throws when all fallbacks fail', () async {
    final fake = FakeProcessRunner(
      failingExecutables: {'wt.exe', 'powershell', 'cmd'},
    );
    final launcher = SystemRepoLauncher(runner: fake, platformOverride: 'windows');
    expect(
      () => launcher.openInTerminal(_repo(r'C:\repo')),
      throwsA(isA<LauncherException>()),
    );
  });

  test('macos uses open -a Terminal', () async {
    final fake = FakeProcessRunner();
    final launcher = SystemRepoLauncher(runner: fake, platformOverride: 'macos');
    await launcher.openInTerminal(_repo('/repo'));
    expect(fake.calls.single.$1, 'open');
    expect(fake.calls.single.$2, ['-a', 'Terminal', '/repo']);
  });

  test('linux tries gnome-terminal first', () async {
    final fake = FakeProcessRunner();
    final launcher = SystemRepoLauncher(runner: fake, platformOverride: 'linux');
    await launcher.openInTerminal(_repo('/repo'));
    expect(fake.calls.single.$1, 'gnome-terminal');
  });
});
```

- [ ] **Step 2: Run tests, expect FAIL (UnimplementedError)**

Run: `flutter test test/application/launcher/repo_launcher_test.dart`
Expected: 6 new failures.

- [ ] **Step 3: Implement `openInTerminal`**

Replace the `openInTerminal` stub with:

```dart
@override
Future<void> openInTerminal(RepoLocation repo) async {
  final chain = _terminalChain(repo.path);
  for (final (exe, args) in chain) {
    final ok = await _runner.startDetached(exe, args);
    if (ok) return;
  }
  throw const LauncherException(
    'No terminal application available. Install Windows Terminal, '
    'gnome-terminal, konsole, or ensure your default terminal is on PATH.',
  );
}

List<(String, List<String>)> _terminalChain(String path) {
  switch (_platform) {
    case 'windows':
      return [
        ('wt.exe', ['-d', path]),
        ('powershell', ['-NoExit', '-WorkingDirectory', path]),
        ('cmd', ['/K', 'cd', '/D', path]),
      ];
    case 'macos':
      return [
        ('open', ['-a', 'Terminal', path]),
      ];
    default:
      return [
        ('gnome-terminal', ['--working-directory=$path']),
        ('konsole', ['--workdir', path]),
        ('xterm', ['-e', 'cd "$path" && \$SHELL']),
      ];
  }
}
```

- [ ] **Step 4: Run tests**

Run: `flutter test test/application/launcher/repo_launcher_test.dart`
Expected: PASS (12 tests total).

- [ ] **Step 5: Commit**

```bash
git add lib/infrastructure/launcher/system_repo_launcher.dart test/application/launcher/repo_launcher_test.dart
git commit -m "feat(launcher): openInTerminal with platform fallback chain"
```

---

## Task 5: Editor detection (TDD)

**Files:**
- Modify: `lib/infrastructure/launcher/system_repo_launcher.dart`
- Modify: `test/application/launcher/repo_launcher_test.dart`

- [ ] **Step 1: Add tests**

```dart
group('SystemRepoLauncher.detectAvailableEditors', () {
  test('returns VS Code when `code` probe succeeds', () async {
    final fake = FakeProcessRunner(probes: {
      'code': const ProcessProbeResult(true, r'C:\Program Files\Microsoft VS Code\bin\code.cmd'),
    });
    final launcher = SystemRepoLauncher(runner: fake, platformOverride: 'windows');
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
    final launcher = SystemRepoLauncher(runner: fake, platformOverride: 'windows');
    final editors = await launcher.detectAvailableEditors();
    final ids = editors.map((e) => e.id).toSet();
    expect(ids, containsAll(['vscode', 'cursor', 'rider']));
  });

  test('returns empty list when no editor detected', () async {
    final fake = FakeProcessRunner();
    final launcher = SystemRepoLauncher(runner: fake, platformOverride: 'linux');
    expect(await launcher.detectAvailableEditors(), isEmpty);
  });

  test('result is cached across calls', () async {
    int probeCount = 0;
    final counting = _CountingRunner(probeCount: () => probeCount, onProbe: () => probeCount++);
    final launcher = SystemRepoLauncher(runner: counting, platformOverride: 'linux');
    await launcher.detectAvailableEditors();
    final firstCount = probeCount;
    await launcher.detectAvailableEditors();
    expect(probeCount, firstCount, reason: 'second call must not re-probe');
  });
});
```

Add the `_CountingRunner` helper (at the bottom of the test file, outside `main`):

```dart
class _CountingRunner implements ProcessRunner {
  final int Function() probeCount;
  final VoidCallback onProbe;
  _CountingRunner({required this.probeCount, required this.onProbe});

  @override
  Future<ProcessProbeResult> probe(String command) async {
    onProbe();
    return const ProcessProbeResult(false, null);
  }

  @override
  Future<bool> startDetached(String executable, List<String> args) async => true;
}
```

Also add this import to the test file:

```dart
import 'package:flutter/foundation.dart' show VoidCallback;
```

- [ ] **Step 2: Run tests, expect FAIL**

Run: `flutter test test/application/launcher/repo_launcher_test.dart`
Expected: 4 new failures.

- [ ] **Step 3: Implement detection**

Add to `SystemRepoLauncher`:

```dart
List<EditorTarget>? _editorCache;

/// Probe table: command(s) to probe → (id, displayName).
/// First matching command wins for each editor.
static const List<({String id, String displayName, List<String> commands})> _editorProbeTable = [
  (id: 'vscode',  displayName: 'VS Code',         commands: ['code', 'code.cmd']),
  (id: 'cursor',  displayName: 'Cursor',          commands: ['cursor', 'cursor.cmd']),
  (id: 'idea',    displayName: 'IntelliJ IDEA',   commands: ['idea64', 'idea']),
  (id: 'webstorm',displayName: 'WebStorm',        commands: ['webstorm64', 'webstorm']),
  (id: 'rider',   displayName: 'Rider',           commands: ['rider64', 'rider']),
  (id: 'sublime', displayName: 'Sublime Text',    commands: ['subl']),
  (id: 'studio',  displayName: 'Android Studio',  commands: ['studio64', 'studio']),
  (id: 'fleet',   displayName: 'Fleet',           commands: ['fleet']),
];

@override
Future<List<EditorTarget>> detectAvailableEditors() async {
  if (_editorCache != null) return _editorCache!;
  final found = <EditorTarget>[];
  for (final entry in _editorProbeTable) {
    for (final cmd in entry.commands) {
      final result = await _runner.probe(cmd);
      if (result.found) {
        found.add(EditorTarget(
          id: entry.id,
          displayName: entry.displayName,
          executable: result.resolvedPath ?? cmd,
        ));
        break;
      }
    }
  }
  _editorCache = List.unmodifiable(found);
  return _editorCache!;
}
```

- [ ] **Step 4: Run tests**

Run: `flutter test test/application/launcher/repo_launcher_test.dart`
Expected: PASS (16 tests total).

- [ ] **Step 5: Commit**

```bash
git add lib/infrastructure/launcher/system_repo_launcher.dart test/application/launcher/repo_launcher_test.dart
git commit -m "feat(launcher): detect available editors on PATH"
```

---

## Task 6: `openInEditor`

**Files:**
- Modify: `lib/infrastructure/launcher/system_repo_launcher.dart`
- Modify: `test/application/launcher/repo_launcher_test.dart`

- [ ] **Step 1: Add tests**

```dart
group('SystemRepoLauncher.openInEditor', () {
  test('starts editor executable with repo path', () async {
    final fake = FakeProcessRunner();
    final launcher = SystemRepoLauncher(runner: fake, platformOverride: 'windows');
    const editor = EditorTarget(id: 'vscode', displayName: 'VS Code', executable: 'code');
    await launcher.openInEditor(_repo(r'C:\repo'), editor);
    expect(fake.calls.single.$1, 'code');
    expect(fake.calls.single.$2, [r'C:\repo']);
  });

  test('throws LauncherException when spawn fails', () async {
    final fake = FakeProcessRunner(failingExecutables: {'code'});
    final launcher = SystemRepoLauncher(runner: fake, platformOverride: 'macos');
    const editor = EditorTarget(id: 'vscode', displayName: 'VS Code', executable: 'code');
    expect(
      () => launcher.openInEditor(_repo('/repo'), editor),
      throwsA(isA<LauncherException>().having((e) => e.message, 'message', contains('VS Code'))),
    );
  });
});
```

- [ ] **Step 2: Run tests, expect FAIL**

Run: `flutter test test/application/launcher/repo_launcher_test.dart`
Expected: 2 new failures (UnimplementedError).

- [ ] **Step 3: Implement**

Replace `openInEditor` stub with:

```dart
@override
Future<void> openInEditor(RepoLocation repo, EditorTarget editor) async {
  final ok = await _runner.startDetached(editor.executable, [repo.path]);
  if (!ok) {
    throw LauncherException('Could not open ${editor.displayName}.');
  }
}
```

- [ ] **Step 4: Run tests**

Run: `flutter test test/application/launcher/repo_launcher_test.dart`
Expected: PASS (18 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/infrastructure/launcher/system_repo_launcher.dart test/application/launcher/repo_launcher_test.dart
git commit -m "feat(launcher): openInEditor with friendly error"
```

---

## Task 7: Wire Riverpod providers

**Files:**
- Modify: `lib/application/providers.dart`

- [ ] **Step 1: Add providers**

Add these imports near the top of `providers.dart`:

```dart
import 'launcher/repo_launcher.dart';
import '../infrastructure/launcher/system_repo_launcher.dart';
```

Add at the bottom of the file:

```dart
final repoLauncherProvider = Provider<RepoLauncher>((ref) {
  return SystemRepoLauncher();
});

final availableEditorsProvider = FutureProvider<List<EditorTarget>>((ref) {
  return ref.watch(repoLauncherProvider).detectAvailableEditors();
});
```

- [ ] **Step 2: Analyze**

Run: `flutter analyze lib/application/providers.dart`
Expected: No issues.

- [ ] **Step 3: Commit**

```bash
git add lib/application/providers.dart
git commit -m "feat(launcher): expose repoLauncher and availableEditors providers"
```

---

## Task 8: `_OpenDropdown` in toolbar

**Files:**
- Modify: `lib/ui/toolbar/git_toolbar.dart`

- [ ] **Step 1: Add imports**

Near the top of `git_toolbar.dart` add:

```dart
import '../../application/launcher/repo_launcher.dart';
```

(`providers.dart` is already imported.)

- [ ] **Step 2: Add `_OpenDropdown` to the toolbar Row**

In `_GitToolbarState.build`, after the `_StashDropdown(...)`:

```dart
const SizedBox(width: 2),
_OpenDropdown(enabled: enabled, repo: repo),
```

- [ ] **Step 3: Add the widget at the bottom of the file (after `_StashDropdownState` block, before the "Branch picker dialog" section)**

```dart
// ---------------------------------------------------------------------------
// Open dropdown — reveal in files / terminal / editor
// ---------------------------------------------------------------------------

class _OpenDropdown extends ConsumerStatefulWidget {
  final bool enabled;
  final RepoLocation? repo;
  const _OpenDropdown({required this.enabled, required this.repo});

  @override
  ConsumerState<_OpenDropdown> createState() => _OpenDropdownState();
}

class _OpenDropdownState extends ConsumerState<_OpenDropdown> {
  final _menuController = MenuController();

  @override
  Widget build(BuildContext context) {
    final editorsAsync = ref.watch(availableEditorsProvider);
    return MenuAnchor(
      controller: _menuController,
      menuChildren: widget.enabled && widget.repo != null
          ? _buildMenuItems(widget.repo!, editorsAsync.valueOrNull ?? const [])
          : const [],
      child: _ToolbarDropdownButton(
        icon: Icons.open_in_new,
        label: 'Open',
        enabled: widget.enabled,
        onTap: () => _menuController.isOpen
            ? _menuController.close()
            : _menuController.open(),
      ),
    );
  }

  List<Widget> _buildMenuItems(RepoLocation repo, List<EditorTarget> editors) {
    final items = <Widget>[
      MenuItemButton(
        leadingIcon: const Icon(Icons.folder_open, size: 14),
        onPressed: () {
          _menuController.close();
          _run(() => ref.read(repoLauncherProvider).revealInFiles(repo));
        },
        child: const Text('Show in file explorer'),
      ),
      MenuItemButton(
        leadingIcon: const Icon(Icons.terminal, size: 14),
        onPressed: () {
          _menuController.close();
          _run(() => ref.read(repoLauncherProvider).openInTerminal(repo));
        },
        child: const Text('Open in terminal'),
      ),
      const Divider(height: 1),
    ];

    if (editors.isEmpty) {
      items.add(MenuItemButton(
        leadingIcon: const Icon(Icons.code, size: 14),
        onPressed: () {
          _menuController.close();
          _run(() => ref.read(repoLauncherProvider).openInEditor(
                repo,
                const EditorTarget(
                    id: 'vscode', displayName: 'VS Code', executable: 'code'),
              ));
        },
        child: const Text('Open in VS Code'),
      ));
    } else {
      for (final editor in editors) {
        items.add(MenuItemButton(
          leadingIcon: const Icon(Icons.code, size: 14),
          onPressed: () {
            _menuController.close();
            _run(() =>
                ref.read(repoLauncherProvider).openInEditor(repo, editor));
          },
          child: Text('Open in ${editor.displayName}'),
        ));
      }
    }
    return items;
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } on LauncherException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }
}
```

- [ ] **Step 4: Analyze**

Run: `flutter analyze lib/ui/toolbar/git_toolbar.dart`
Expected: No issues.

- [ ] **Step 5: Run full test suite**

Run: `flutter test`
Expected: All tests pass (existing + 18 new launcher tests).

- [ ] **Step 6: Commit**

```bash
git add lib/ui/toolbar/git_toolbar.dart
git commit -m "feat(toolbar): add Open dropdown (files / terminal / editor)"
```

---

## Task 9: Manual verification on Windows

**No code; verify the feature works end-to-end.**

- [ ] **Step 1: Launch app**

Run: `flutter run -d windows`

- [ ] **Step 2: Activate a repo in the workspace**

Open any existing repo from the sidebar.

- [ ] **Step 3: Click "Open" dropdown**

- Click *Show in file explorer* → Windows Explorer opens at the repo root.
- Click *Open in terminal* → Windows Terminal opens at the repo root (if installed); otherwise PowerShell.
- Click *Open in VS Code* (or whichever editors were detected) → editor opens with the repo.

- [ ] **Step 4: Test error path**

Temporarily rename `code.cmd` (or use a machine without VS Code) → the menu should NOT show "Open in VS Code" (since detection found nothing). If you explicitly click the "fallback VS Code" option when no editor was detected, a SnackBar should appear saying "Could not open VS Code."

- [ ] **Step 5: Final state check**

Run: `git status`
Expected: clean tree, no uncommitted changes.

---

## Self-review (executed)

**Spec coverage:**
- Toolbar dropdown — Task 8 ✓
- `RepoLauncher` interface + `EditorTarget` + `LauncherException` — Task 1 ✓
- `SystemRepoLauncher` impl in `infrastructure/launcher/` — Tasks 3–6 ✓
- Files/terminal/editor commands per platform — Tasks 3, 4, 6 ✓
- Fallback chain (terminal) — Task 4 ✓
- Editor detection with PATH probe, cached — Task 5 ✓
- Providers (`repoLauncherProvider`, `availableEditorsProvider`) — Task 7 ✓
- Error → SnackBar — Task 8, `_run` helper ✓
- Unit tests with fake runner — Tasks 3–6 ✓
- Manual verification — Task 9 ✓

**Placeholder scan:** No TBDs, no "implement later". Each code step has full source.

**Type consistency:**
- `EditorTarget` fields `id`/`displayName`/`executable` consistent across Tasks 1, 5, 6, 8.
- `ProcessProbeResult(bool, String?)` consistent between Tasks 2, 5.
- `(String, List<String>)` records used consistently in `_terminalChain` and tests.

**Scope:** One coherent slice, ~9 tasks, ~2–4 hours.
