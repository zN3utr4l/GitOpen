# GitOpen Slice 3 (Distribution & Polish) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn GitOpen into a polished, distributable product — Settings UI with full configurability, light theme, custom keybindings, MSIX/AppImage packaging with GitHub Actions release pipeline, Velopack auto-update, status bar, and the `revert` operation.

**Architecture:** Existing layered Domain/Application/Infrastructure/Ui structure stays. All hard-coded colours move into `AppPalette` (Flutter `ThemeExtension`); two concrete palettes (dark, light) selected via Riverpod `appSettingsProvider`. Settings persisted in the existing drift `settings` table (key + JSON value). Packaging uses the official `msix` Dart package for Windows and a `bash` + `appimagetool` script for Linux, both wired into a GitHub Actions release workflow triggered by `v*.*.*` tags. Velopack auto-update sources release artefacts from public GitHub Releases.

**Tech Stack:** Existing Flutter/Dart + drift + Riverpod + bitsdojo_window. New: `msix` (dev), `velopack_flutter`.

**Reading order:** Sub-slices 3A → 3E. Each sub-slice ends in a buildable, testable state.

**Conventions:**
- Repo root: `C:\Users\s.porta\Documents\GitOpen`. Don't touch `legacy/`.
- All TDD-flagged tasks: failing test → implement → green → commit.
- Each task ends with: `flutter analyze` 0 issues + `flutter test` (and `flutter build windows --debug` for UI tasks).
- Commits use trailer `Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>`.
- Set `$env:NO_PROXY = "localhost,127.0.0.1"` before `flutter test`.
- Flutter at `C:\src\flutter\bin\flutter.bat`.
- Kill `gitopen.exe` (`Get-Process -Name gitopen -EA SilentlyContinue | Stop-Process -Force`) before any `flutter build windows --debug`.

---

## Sub-slice 3A — Theme + Settings foundation

### Task A1: AppPalette ThemeExtension

**Files:**
- Create: `lib/ui/theme/app_palette.dart`
- Create: `test/ui/theme/app_palette_test.dart`

- [ ] **Step 1: Failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:gitopen/ui/theme/app_palette.dart';

void main() {
  test('AppPalette.dark and .light produce distinct fg0', () {
    expect(AppPalette.dark().fg0, isNot(AppPalette.light().fg0));
  });

  test('copyWith preserves untouched fields', () {
    final dark = AppPalette.dark();
    final modified = dark.copyWith(fg0: const Color(0xFFEEEEEE));
    expect(modified.fg0, const Color(0xFFEEEEEE));
    expect(modified.bg0, dark.bg0);
  });
}
```

- [ ] **Step 2: Implement** at `lib/ui/theme/app_palette.dart`:

```dart
import 'package:flutter/material.dart';

@immutable
final class AppPalette extends ThemeExtension<AppPalette> {
  final Color bg0, bg1, bg2, bg3, bg4, bg5, bgAccent;
  final Color border, borderStrong;
  final Color fg0, fg1, fg2, fg3;
  final Color accentCurrent, accentTag, accentRemote, accentWarn, accentErr;
  final List<Color> lanePalette;

  const AppPalette({
    required this.bg0, required this.bg1, required this.bg2, required this.bg3,
    required this.bg4, required this.bg5, required this.bgAccent,
    required this.border, required this.borderStrong,
    required this.fg0, required this.fg1, required this.fg2, required this.fg3,
    required this.accentCurrent, required this.accentTag, required this.accentRemote,
    required this.accentWarn, required this.accentErr,
    required this.lanePalette,
  });

  factory AppPalette.dark() => const AppPalette(
    bg0: Color(0xFF1A1A1D), bg1: Color(0xFF1F1F23), bg2: Color(0xFF25252A),
    bg3: Color(0xFF2C2C31), bg4: Color(0xFF34343A), bg5: Color(0xFF3D3D44),
    bgAccent: Color(0xFF094771),
    border: Color(0xFF313137), borderStrong: Color(0xFF404048),
    fg0: Color(0xFFD4D4D4), fg1: Color(0xFFB8B8BC),
    fg2: Color(0xFF888892), fg3: Color(0xFF5D5D65),
    accentCurrent: Color(0xFF4EC9B0), accentTag: Color(0xFFD7BA7D),
    accentRemote: Color(0xFF569CD6), accentWarn: Color(0xFFCE9178),
    accentErr: Color(0xFFF48771),
    lanePalette: [
      Color(0xFF5FB3A1), Color(0xFFD6C068), Color(0xFF6FA8DC), Color(0xFFC97C5D),
      Color(0xFFB787B3), Color(0xFF7A98C9), Color(0xFFC79A5D), Color(0xFFC97078),
    ],
  );

  factory AppPalette.light() => const AppPalette(
    bg0: Color(0xFFFAFAFB), bg1: Color(0xFFFFFFFF), bg2: Color(0xFFF4F4F6),
    bg3: Color(0xFFECECEE), bg4: Color(0xFFE4E4E7), bg5: Color(0xFFD8D8DC),
    bgAccent: Color(0xFFCFE5FF),
    border: Color(0xFFD8D8DC), borderStrong: Color(0xFFC0C0C7),
    fg0: Color(0xFF202024), fg1: Color(0xFF414148),
    fg2: Color(0xFF6E6E78), fg3: Color(0xFF9A9AA2),
    accentCurrent: Color(0xFF1B9E83), accentTag: Color(0xFFA87514),
    accentRemote: Color(0xFF2A6BB1), accentWarn: Color(0xFFA0552C),
    accentErr: Color(0xFFB92C2C),
    lanePalette: [
      Color(0xFF2B8C73), Color(0xFF8E7A1C), Color(0xFF2A6BB1), Color(0xFFA0552C),
      Color(0xFF7E4B7C), Color(0xFF456493), Color(0xFF8F6A1C), Color(0xFFA84858),
    ],
  );

  @override
  AppPalette copyWith({
    Color? bg0, Color? bg1, Color? bg2, Color? bg3, Color? bg4, Color? bg5,
    Color? bgAccent, Color? border, Color? borderStrong,
    Color? fg0, Color? fg1, Color? fg2, Color? fg3,
    Color? accentCurrent, Color? accentTag, Color? accentRemote,
    Color? accentWarn, Color? accentErr,
    List<Color>? lanePalette,
  }) {
    return AppPalette(
      bg0: bg0 ?? this.bg0, bg1: bg1 ?? this.bg1, bg2: bg2 ?? this.bg2,
      bg3: bg3 ?? this.bg3, bg4: bg4 ?? this.bg4, bg5: bg5 ?? this.bg5,
      bgAccent: bgAccent ?? this.bgAccent,
      border: border ?? this.border, borderStrong: borderStrong ?? this.borderStrong,
      fg0: fg0 ?? this.fg0, fg1: fg1 ?? this.fg1,
      fg2: fg2 ?? this.fg2, fg3: fg3 ?? this.fg3,
      accentCurrent: accentCurrent ?? this.accentCurrent,
      accentTag: accentTag ?? this.accentTag,
      accentRemote: accentRemote ?? this.accentRemote,
      accentWarn: accentWarn ?? this.accentWarn,
      accentErr: accentErr ?? this.accentErr,
      lanePalette: lanePalette ?? this.lanePalette,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      bg0: Color.lerp(bg0, other.bg0, t)!, bg1: Color.lerp(bg1, other.bg1, t)!,
      bg2: Color.lerp(bg2, other.bg2, t)!, bg3: Color.lerp(bg3, other.bg3, t)!,
      bg4: Color.lerp(bg4, other.bg4, t)!, bg5: Color.lerp(bg5, other.bg5, t)!,
      bgAccent: Color.lerp(bgAccent, other.bgAccent, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      fg0: Color.lerp(fg0, other.fg0, t)!, fg1: Color.lerp(fg1, other.fg1, t)!,
      fg2: Color.lerp(fg2, other.fg2, t)!, fg3: Color.lerp(fg3, other.fg3, t)!,
      accentCurrent: Color.lerp(accentCurrent, other.accentCurrent, t)!,
      accentTag: Color.lerp(accentTag, other.accentTag, t)!,
      accentRemote: Color.lerp(accentRemote, other.accentRemote, t)!,
      accentWarn: Color.lerp(accentWarn, other.accentWarn, t)!,
      accentErr: Color.lerp(accentErr, other.accentErr, t)!,
      lanePalette: lanePalette, // not lerped — palette swap is discrete
    );
  }

  static AppPalette of(BuildContext context) =>
      Theme.of(context).extension<AppPalette>()!;
}
```

- [ ] **Step 3: Run tests + commit**

```powershell
$env:NO_PROXY="localhost,127.0.0.1"
& 'C:\src\flutter\bin\flutter.bat' test test/ui/theme
& 'C:\src\flutter\bin\flutter.bat' analyze
```

```bash
git add lib/ui/theme test
git -c user.email=s.porta@novomatic.it -c user.name=s.porta commit -m "feat(ui): AppPalette ThemeExtension with dark + light variants"
```

---

### Task A2: AppSettings StateNotifier + drift schema additions

**Files:**
- Create: `lib/application/settings/app_settings.dart`
- Create: `lib/application/settings/app_settings_notifier.dart`
- Create: `lib/infrastructure/persistence/settings_repository.dart`
- Modify: `lib/application/providers.dart`
- Create: `test/application/settings/app_settings_test.dart`

- [ ] **Step 1: AppSettings state record**

`lib/application/settings/app_settings.dart`:
```dart
import 'package:flutter/services.dart';
import 'package:equatable/equatable.dart';

enum AppTheme { dark, light }
enum DefaultPullStrategy { ffOnly, merge, rebase }

final class AppSettingsState extends Equatable {
  final AppTheme theme;
  final String? externalEditorPath;
  final DefaultPullStrategy defaultPullStrategy;
  final bool commitSignoffDefault;
  final int fontSize;
  final String? fontFamily;
  final String? githubClientId;
  final bool autoUpdateCheck;
  final Map<String, LogicalKeySet> keybindings;

  const AppSettingsState({
    this.theme = AppTheme.dark,
    this.externalEditorPath,
    this.defaultPullStrategy = DefaultPullStrategy.merge,
    this.commitSignoffDefault = false,
    this.fontSize = 12,
    this.fontFamily,
    this.githubClientId,
    this.autoUpdateCheck = true,
    this.keybindings = const {},
  });

  AppSettingsState copyWith({
    AppTheme? theme,
    String? externalEditorPath,
    DefaultPullStrategy? defaultPullStrategy,
    bool? commitSignoffDefault,
    int? fontSize,
    String? fontFamily,
    String? githubClientId,
    bool? autoUpdateCheck,
    Map<String, LogicalKeySet>? keybindings,
  }) {
    return AppSettingsState(
      theme: theme ?? this.theme,
      externalEditorPath: externalEditorPath ?? this.externalEditorPath,
      defaultPullStrategy: defaultPullStrategy ?? this.defaultPullStrategy,
      commitSignoffDefault: commitSignoffDefault ?? this.commitSignoffDefault,
      fontSize: fontSize ?? this.fontSize,
      fontFamily: fontFamily ?? this.fontFamily,
      githubClientId: githubClientId ?? this.githubClientId,
      autoUpdateCheck: autoUpdateCheck ?? this.autoUpdateCheck,
      keybindings: keybindings ?? this.keybindings,
    );
  }

  @override
  List<Object?> get props => [
    theme, externalEditorPath, defaultPullStrategy, commitSignoffDefault,
    fontSize, fontFamily, githubClientId, autoUpdateCheck, keybindings,
  ];
}
```

- [ ] **Step 2: SettingsRepository** at `lib/infrastructure/persistence/settings_repository.dart`:

```dart
import 'dart:convert';
import 'package:drift/drift.dart';
import 'database.dart';

class SettingsRepository {
  final AppDatabase _db;
  SettingsRepository(this._db);

  Future<Map<String, dynamic>> readAll() async {
    final rows = await _db.select(_db.settings).get();
    final result = <String, dynamic>{};
    for (final row in rows) {
      try {
        result[row.key] = jsonDecode(row.valueJson);
      } catch (_) {
        // tolerate legacy raw strings
        result[row.key] = row.valueJson;
      }
    }
    return result;
  }

  Future<void> put(String key, dynamic value) async {
    final json = jsonEncode(value);
    await _db.into(_db.settings).insertOnConflictUpdate(
      SettingsCompanion.insert(key: key, valueJson: json),
    );
  }
}
```

- [ ] **Step 3: AppSettingsNotifier** at `lib/application/settings/app_settings_notifier.dart`:

```dart
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../infrastructure/persistence/settings_repository.dart';
import 'app_settings.dart';

const _defaultBindings = <String, List<int>>{
  'commit': [LogicalKeyboardKey.controlLeft, LogicalKeyboardKey.enter],
  'commitAndPush': [LogicalKeyboardKey.controlLeft, LogicalKeyboardKey.shiftLeft, LogicalKeyboardKey.enter],
  'fetch': [LogicalKeyboardKey.f5],
  'refresh': [LogicalKeyboardKey.controlLeft, LogicalKeyboardKey.keyR],
  'openRepoSelector': [LogicalKeyboardKey.controlLeft, LogicalKeyboardKey.keyT],
  'openSettings': [LogicalKeyboardKey.controlLeft, LogicalKeyboardKey.comma],
};

class AppSettingsNotifier extends StateNotifier<AppSettingsState> {
  final SettingsRepository _repo;
  AppSettingsNotifier(this._repo) : super(_defaults()) {
    _load();
  }

  static AppSettingsState _defaults() {
    final defaults = <String, LogicalKeySet>{};
    for (final entry in _defaultBindings.entries) {
      defaults[entry.key] = LogicalKeySet.fromSet(
        entry.value.map((id) => LogicalKeyboardKey.findKeyByKeyId(id)!).toSet(),
      );
    }
    return AppSettingsState(keybindings: defaults);
  }

  Future<void> _load() async {
    final all = await _repo.readAll();
    state = AppSettingsState(
      theme: _enumFromString(all['theme'], AppTheme.values, AppTheme.dark),
      externalEditorPath: all['external_editor_path'] as String?,
      defaultPullStrategy: _enumFromString(all['default_pull_strategy'], DefaultPullStrategy.values, DefaultPullStrategy.merge),
      commitSignoffDefault: (all['commit_signoff_default'] as bool?) ?? false,
      fontSize: (all['font_size'] as int?) ?? 12,
      fontFamily: all['font_family'] as String?,
      githubClientId: all['github_client_id'] as String?,
      autoUpdateCheck: (all['auto_update_check'] as bool?) ?? true,
      keybindings: _decodeBindings(all['keybindings']) ?? state.keybindings,
    );
  }

  Future<void> setTheme(AppTheme v) async {
    state = state.copyWith(theme: v);
    await _repo.put('theme', v.name);
  }

  Future<void> setExternalEditorPath(String? v) async {
    state = state.copyWith(externalEditorPath: v);
    await _repo.put('external_editor_path', v);
  }

  Future<void> setDefaultPullStrategy(DefaultPullStrategy v) async {
    state = state.copyWith(defaultPullStrategy: v);
    await _repo.put('default_pull_strategy', v.name);
  }

  Future<void> setCommitSignoffDefault(bool v) async {
    state = state.copyWith(commitSignoffDefault: v);
    await _repo.put('commit_signoff_default', v);
  }

  Future<void> setFontSize(int v) async {
    state = state.copyWith(fontSize: v);
    await _repo.put('font_size', v);
  }

  Future<void> setFontFamily(String? v) async {
    state = state.copyWith(fontFamily: v);
    await _repo.put('font_family', v);
  }

  Future<void> setGithubClientId(String? v) async {
    state = state.copyWith(githubClientId: v);
    await _repo.put('github_client_id', v);
  }

  Future<void> setAutoUpdateCheck(bool v) async {
    state = state.copyWith(autoUpdateCheck: v);
    await _repo.put('auto_update_check', v);
  }

  Future<void> setKeybinding(String action, LogicalKeySet keys) async {
    final next = Map<String, LogicalKeySet>.from(state.keybindings);
    next[action] = keys;
    state = state.copyWith(keybindings: next);
    await _repo.put('keybindings', _encodeBindings(next));
  }

  Future<void> resetKeybinding(String action) async {
    final defaults = _defaults().keybindings;
    if (!defaults.containsKey(action)) return;
    await setKeybinding(action, defaults[action]!);
  }

  T _enumFromString<T extends Enum>(dynamic v, List<T> values, T fallback) {
    if (v is! String) return fallback;
    return values.firstWhere((e) => e.name == v, orElse: () => fallback);
  }

  Map<String, LogicalKeySet>? _decodeBindings(dynamic v) {
    if (v is! Map) return null;
    final result = <String, LogicalKeySet>{};
    v.forEach((key, value) {
      if (key is String && value is List) {
        final ids = value.cast<int>();
        final keys = ids.map(LogicalKeyboardKey.findKeyByKeyId).whereType<LogicalKeyboardKey>().toSet();
        if (keys.isNotEmpty) result[key] = LogicalKeySet.fromSet(keys);
      }
    });
    return result;
  }

  Map<String, List<int>> _encodeBindings(Map<String, LogicalKeySet> b) {
    return {
      for (final entry in b.entries)
        entry.key: entry.value.keys.map((k) => k.keyId).toList(),
    };
  }
}
```

- [ ] **Step 4: Provider** in `lib/application/providers.dart` (append):

```dart
final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository(ref.watch(appDatabaseProvider));
});

final appSettingsProvider = StateNotifierProvider<AppSettingsNotifier, AppSettingsState>((ref) {
  return AppSettingsNotifier(ref.watch(settingsRepositoryProvider));
});
```

Add the necessary imports.

- [ ] **Step 5: Tests** at `test/application/settings/app_settings_test.dart`:

```dart
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitopen/application/settings/app_settings.dart';
import 'package:gitopen/application/settings/app_settings_notifier.dart';
import 'package:gitopen/infrastructure/persistence/settings_repository.dart';
import '../../_helpers/in_memory_db.dart';

void main() {
  test('default state is dark theme + merge strategy', () async {
    final db = newInMemoryDb();
    final notifier = AppSettingsNotifier(SettingsRepository(db));
    await Future.delayed(const Duration(milliseconds: 50));
    expect(notifier.state.theme, AppTheme.dark);
    expect(notifier.state.defaultPullStrategy, DefaultPullStrategy.merge);
    expect(notifier.state.commitSignoffDefault, isFalse);
    await db.close();
  });

  test('setTheme persists and re-loads', () async {
    final db = newInMemoryDb();
    final notifier = AppSettingsNotifier(SettingsRepository(db));
    await Future.delayed(const Duration(milliseconds: 50));
    await notifier.setTheme(AppTheme.light);
    expect(notifier.state.theme, AppTheme.light);
    // New notifier on same DB hydrates the saved value
    final fresh = AppSettingsNotifier(SettingsRepository(db));
    await Future.delayed(const Duration(milliseconds: 50));
    expect(fresh.state.theme, AppTheme.light);
    await db.close();
  });

  test('setKeybinding stores key combo and round-trips', () async {
    final db = newInMemoryDb();
    final notifier = AppSettingsNotifier(SettingsRepository(db));
    await Future.delayed(const Duration(milliseconds: 50));
    final combo = LogicalKeySet(LogicalKeyboardKey.controlLeft, LogicalKeyboardKey.keyS);
    await notifier.setKeybinding('commit', combo);
    final fresh = AppSettingsNotifier(SettingsRepository(db));
    await Future.delayed(const Duration(milliseconds: 50));
    expect(fresh.state.keybindings['commit'], combo);
    await db.close();
  });
}
```

- [ ] **Step 6: Run + commit**

```bash
& 'C:\src\flutter\bin\flutter.bat' test test/application/settings
& 'C:\src\flutter\bin\flutter.bat' analyze
git add lib test
git -c user.email=s.porta@novomatic.it -c user.name=s.porta commit -m "feat(app): AppSettings StateNotifier + SettingsRepository (TDD)"
```

---

### Task A3: themeProvider wiring + MaterialApp consumption

**Files:**
- Modify: `lib/main.dart`

- [ ] **Step 1: Replace `GitOpenApp` to consume themeProvider**

In `lib/main.dart`, change `GitOpenApp` from `StatelessWidget` to `ConsumerWidget`. Build `MaterialApp.theme` reactively. Read both light + dark `ThemeData` from `appSettingsProvider.theme`.

```dart
class GitOpenApp extends ConsumerWidget {
  const GitOpenApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(appSettingsProvider.select((s) => s.theme));
    final palette = theme == AppTheme.dark ? AppPalette.dark() : AppPalette.light();
    return MaterialApp(
      title: 'GitOpen',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: theme == AppTheme.dark ? Brightness.dark : Brightness.light,
        scaffoldBackgroundColor: palette.bg1,
        extensions: [palette],
      ),
      home: const Shell(),
    );
  }
}
```

Add imports: `application/settings/app_settings.dart`, `ui/theme/app_palette.dart`.

- [ ] **Step 2: Build + commit**

```bash
& 'C:\src\flutter\bin\flutter.bat' analyze
& 'C:\src\flutter\bin\flutter.bat' build windows --debug
git add lib/main.dart
git -c user.email=s.porta@novomatic.it -c user.name=s.porta commit -m "feat(ui): themeProvider wiring via appSettingsProvider in MaterialApp"
```

---

### Task A4: Refactor widgets to read from AppPalette — title bar + repo selector + sidebar

**Files:**
- Modify: `lib/main.dart` (TitleBar, Brand, WindowControls colours)
- Modify: `lib/ui/shell/repo_selector.dart`
- Modify: `lib/ui/sidebar/sidebar.dart`
- Modify: `lib/ui/sidebar/branch_tree_view.dart`

- [ ] **Step 1: Pattern**

Replace every `const Color(0xFFxxxxxx)` colour literal with the corresponding palette field. Strategy per widget:
- In each `build(BuildContext context)` add: `final p = AppPalette.of(context);`
- Replace hard-coded colours with `p.bg2`, `p.fg0`, etc., according to the mapping in the spec §2.1 table.
- Some `Color` literals were inside `const` constructors — those constructors lose their `const` modifier when the colour becomes dynamic. Acceptable.

Apply this to TitleBar + RepoSelector + Sidebar + BranchTreeView. The remaining widgets are done in A5 and A6.

- [ ] **Step 2: Verify**

```bash
& 'C:\src\flutter\bin\flutter.bat' analyze
& 'C:\src\flutter\bin\flutter.bat' build windows --debug
& 'C:\src\flutter\bin\flutter.bat' test
```

- [ ] **Step 3: Commit**

```bash
git add lib
git -c user.email=s.porta@novomatic.it -c user.name=s.porta commit -m "refactor(ui): title bar + repo selector + sidebar read AppPalette"
```

---

### Task A5: Refactor commit graph + working copy to AppPalette

**Files:**
- Modify: `lib/ui/commit_graph/commit_row.dart`
- Modify: `lib/ui/commit_graph/commit_graph_panel.dart`
- Modify: `lib/ui/commit_graph/local_changes_row.dart`
- Modify: `lib/ui/commit_graph/ref_pill.dart`
- Modify: `lib/ui/commit_graph/lane_painter.dart` (lane palette via `AppPalette.lanePalette`)
- Modify: `lib/ui/working_copy/working_copy_panel.dart`
- Modify: `lib/ui/working_copy/commit_compose.dart`

- [ ] **Step 1: Same pattern as A4**

Critical case: `lane_painter.dart` currently exposes a `const List<Color> kLanePalette = [...]` constant. Convert `LanePainter` to accept the lane palette via its constructor parameter (or via a callback for `laneColor(idx, palette)`). The painter is created per row — palette is passed from `CommitRow.build` where `AppPalette.of(context)` is available.

Update `LanePainter` constructor:
```dart
class LanePainter extends CustomPainter {
  final CommitNode node;
  final int maxLane;
  final List<Color> lanePalette;
  const LanePainter({required this.node, required this.maxLane, required this.lanePalette});
  ...
  Color _laneColor(int idx) => lanePalette[idx.abs() % lanePalette.length];
}
```

And in `CommitRow.build`:
```dart
final palette = AppPalette.of(context);
... CustomPaint(painter: LanePainter(node: node, maxLane: maxLane, lanePalette: palette.lanePalette))
```

- [ ] **Step 2: Verify + commit**

```bash
& 'C:\src\flutter\bin\flutter.bat' analyze
& 'C:\src\flutter\bin\flutter.bat' build windows --debug
& 'C:\src\flutter\bin\flutter.bat' test
git add lib
git -c user.email=s.porta@novomatic.it -c user.name=s.porta commit -m "refactor(ui): commit graph + working copy read AppPalette"
```

---

### Task A6: Refactor bottom panel + dialogs + toast + operations to AppPalette

**Files:**
- Modify: `lib/ui/bottom_panel/bottom_panel.dart`
- Modify: `lib/ui/bottom_panel/commit_details_view.dart`
- Modify: `lib/ui/bottom_panel/diff_view.dart`
- Modify: `lib/ui/bottom_panel/file_tree_view.dart`
- Modify: `lib/ui/dialogs/auth_dialog.dart`
- Modify: `lib/ui/dialogs/branch_create_dialog.dart`
- Modify: `lib/ui/dialogs/clone_dialog.dart`
- Modify: `lib/ui/dialogs/confirm_dialog.dart`
- Modify: `lib/ui/operations/toast_overlay.dart`
- Modify: `lib/ui/operations/activity_panel.dart`
- Modify: `lib/ui/conflicts/conflict_resolution_panel.dart`
- Modify: `lib/ui/toolbar/git_toolbar.dart`
- Modify: `lib/ui/welcome/welcome_screen.dart`

- [ ] **Step 1: Same pattern as A4/A5**

All remaining widgets read `AppPalette.of(context)` and use palette fields.

- [ ] **Step 2: Verify + commit**

```bash
& 'C:\src\flutter\bin\flutter.bat' analyze
& 'C:\src\flutter\bin\flutter.bat' build windows --debug
& 'C:\src\flutter\bin\flutter.bat' test
git add lib
git -c user.email=s.porta@novomatic.it -c user.name=s.porta commit -m "refactor(ui): remaining widgets read AppPalette (slice 3A done)"
```

---

### Task A7: Settings page shell

**Files:**
- Create: `lib/ui/settings/settings_page.dart`
- Create: `lib/ui/settings/settings_section.dart`
- Create: `lib/ui/settings/sections/general_section.dart` (placeholder)
- Create: `lib/ui/settings/sections/authentication_section.dart` (placeholder)
- Create: `lib/ui/settings/sections/keybindings_section.dart` (placeholder)
- Create: `lib/ui/settings/sections/github_section.dart` (placeholder)
- Create: `lib/ui/settings/sections/updates_section.dart` (placeholder)
- Create: `lib/ui/settings/sections/about_section.dart` (real — small)
- Create: `lib/application/settings/settings_open_provider.dart`
- Modify: `lib/main.dart` — add ⚙ icon + routing

- [ ] **Step 1: Provider** at `lib/application/settings/settings_open_provider.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

final settingsOpenProvider = StateProvider<bool>((_) => false);
```

- [ ] **Step 2: SettingsPage shell**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/settings/settings_open_provider.dart';
import '../theme/app_palette.dart';
import 'sections/about_section.dart';
import 'sections/authentication_section.dart';
import 'sections/general_section.dart';
import 'sections/github_section.dart';
import 'sections/keybindings_section.dart';
import 'sections/updates_section.dart';

enum SettingsSectionId { general, authentication, keybindings, github, updates, about }

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});
  @override
  ConsumerState<SettingsPage> createState() => _State();
}

class _State extends ConsumerState<SettingsPage> {
  SettingsSectionId _selected = SettingsSectionId.general;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Container(
      color: p.bg1,
      child: Row(children: [
        Container(
          width: 220, color: p.bg2,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                Text('Settings', style: TextStyle(color: p.fg0, fontSize: 14, fontWeight: FontWeight.w600)),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.close, size: 16, color: p.fg1),
                  onPressed: () => ref.read(settingsOpenProvider.notifier).state = false,
                ),
              ]),
            ),
            for (final s in SettingsSectionId.values)
              _NavItem(
                section: s,
                selected: s == _selected,
                onSelect: () => setState(() => _selected = s),
              ),
          ]),
        ),
        Expanded(child: _renderSection(_selected)),
      ]),
    );
  }

  Widget _renderSection(SettingsSectionId s) {
    switch (s) {
      case SettingsSectionId.general: return const GeneralSection();
      case SettingsSectionId.authentication: return const AuthenticationSection();
      case SettingsSectionId.keybindings: return const KeybindingsSection();
      case SettingsSectionId.github: return const GitHubSection();
      case SettingsSectionId.updates: return const UpdatesSection();
      case SettingsSectionId.about: return const AboutSection();
    }
  }
}

class _NavItem extends StatelessWidget {
  final SettingsSectionId section;
  final bool selected;
  final VoidCallback onSelect;
  const _NavItem({required this.section, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return InkWell(
      onTap: onSelect,
      child: Container(
        color: selected ? p.bg4 : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Text(_label(section), style: TextStyle(color: selected ? p.fg0 : p.fg1, fontSize: 13)),
      ),
    );
  }

  String _label(SettingsSectionId s) {
    return switch (s) {
      SettingsSectionId.general => 'General',
      SettingsSectionId.authentication => 'Authentication',
      SettingsSectionId.keybindings => 'Keybindings',
      SettingsSectionId.github => 'GitHub',
      SettingsSectionId.updates => 'Updates',
      SettingsSectionId.about => 'About',
    };
  }
}
```

- [ ] **Step 3: Section placeholders** — 5 stubs identical pattern:

`lib/ui/settings/sections/general_section.dart`:
```dart
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
```

Repeat for `authentication_section.dart`, `keybindings_section.dart`, `github_section.dart`, `updates_section.dart` with their respective labels.

- [ ] **Step 4: AboutSection** (real content):

```dart
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
```

- [ ] **Step 5: Wire ⚙ icon + routing in main.dart**

In `_TitleBar`, add a settings icon between the right MoveWindow spacer and `_WindowControls`. In `Shell.build`, when `settingsOpenProvider` is true, render `SettingsPage` instead of the main panel (replaces both `CommitGraphPanel` + `BottomPanel`).

```dart
// in _TitleBar:
IconButton(
  icon: Icon(Icons.settings, size: 16, color: AppPalette.of(context).fg1),
  onPressed: () {
    final ref = ProviderScope.containerOf(context).read(settingsOpenProvider.notifier);
    ref.state = true;
  },
),

// in Shell.build, replace the inner active-workspace Container child:
child: active == null
    ? WelcomeScreen()
    : settingsOpen
        ? const SettingsPage()
        : Column(/* graph + bottom */),
```

Add imports.

- [ ] **Step 6: Build + commit**

```bash
& 'C:\src\flutter\bin\flutter.bat' analyze
& 'C:\src\flutter\bin\flutter.bat' build windows --debug
git add lib
git -c user.email=s.porta@novomatic.it -c user.name=s.porta commit -m "feat(ui): Settings page shell with ⚙ trigger and section navigation"
```

---

## Sub-slice 3B — Settings content

### Task B1: General section (real content)

**Files:**
- Modify: `lib/ui/settings/sections/general_section.dart`

- [ ] **Step 1: Implement**

```dart
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../application/settings/app_settings.dart';
import '../../../application/providers.dart';
import '../../theme/app_palette.dart';

class GeneralSection extends ConsumerWidget {
  const GeneralSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = AppPalette.of(context);
    final s = ref.watch(appSettingsProvider);
    final notifier = ref.read(appSettingsProvider.notifier);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _SectionHeader('Appearance'),
        _Row(label: 'Theme', child: SegmentedButton<AppTheme>(
          segments: const [
            ButtonSegment(value: AppTheme.dark, label: Text('Dark')),
            ButtonSegment(value: AppTheme.light, label: Text('Light')),
          ],
          selected: {s.theme},
          onSelectionChanged: (v) => notifier.setTheme(v.first),
        )),
        _Row(label: 'Font size', child: SizedBox(
          width: 80,
          child: TextFormField(
            initialValue: '${s.fontSize}',
            keyboardType: TextInputType.number,
            onFieldSubmitted: (v) {
              final i = int.tryParse(v);
              if (i != null && i >= 10 && i <= 24) notifier.setFontSize(i);
            },
          ),
        )),
        const SizedBox(height: 24),
        _SectionHeader('Editor'),
        _Row(label: 'External editor', child: Row(children: [
          Expanded(child: TextFormField(
            initialValue: s.externalEditorPath ?? '',
            onFieldSubmitted: (v) => notifier.setExternalEditorPath(v.isEmpty ? null : v),
            decoration: const InputDecoration(hintText: 'Leave empty for system default'),
          )),
          IconButton(
            icon: const Icon(Icons.folder_open),
            onPressed: () async {
              final group = const XTypeGroup(label: 'Executable', extensions: ['exe']);
              final f = await openFile(acceptedTypeGroups: [group]);
              if (f != null) notifier.setExternalEditorPath(f.path);
            },
          ),
        ])),
        const SizedBox(height: 24),
        _SectionHeader('Git defaults'),
        _Row(label: 'Pull strategy', child: DropdownButton<DefaultPullStrategy>(
          value: s.defaultPullStrategy,
          items: const [
            DropdownMenuItem(value: DefaultPullStrategy.merge, child: Text('Merge')),
            DropdownMenuItem(value: DefaultPullStrategy.rebase, child: Text('Rebase')),
            DropdownMenuItem(value: DefaultPullStrategy.ffOnly, child: Text('Fast-forward only')),
          ],
          onChanged: (v) { if (v != null) notifier.setDefaultPullStrategy(v); },
        )),
        _Row(label: 'Sign-off by default', child: Switch(
          value: s.commitSignoffDefault,
          onChanged: notifier.setCommitSignoffDefault,
        )),
      ]),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);
  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(text.toUpperCase(), style: TextStyle(
        color: p.fg2, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5,
      )),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final Widget child;
  const _Row({required this.label, required this.child});
  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(children: [
        SizedBox(width: 180, child: Text(label, style: TextStyle(color: p.fg1, fontSize: 13))),
        Expanded(child: child),
      ]),
    );
  }
}
```

- [ ] **Step 2: Build + commit**

```bash
& 'C:\src\flutter\bin\flutter.bat' analyze
git add lib
git -c user.email=s.porta@novomatic.it -c user.name=s.porta commit -m "feat(ui): Settings → General section (theme/font/editor/pull/signoff)"
```

---

### Task B2: GitHub section (client_id)

**Files:**
- Modify: `lib/ui/settings/sections/github_section.dart`
- Modify: `lib/infrastructure/auth/github_device_flow.dart` — read client_id from settings

- [ ] **Step 1: GitHubSection**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../application/providers.dart';
import '../../theme/app_palette.dart';

class GitHubSection extends ConsumerStatefulWidget {
  const GitHubSection({super.key});
  @override
  ConsumerState<GitHubSection> createState() => _State();
}

class _State extends ConsumerState<GitHubSection> {
  late final TextEditingController _ctl;

  @override
  void initState() {
    super.initState();
    final s = ref.read(appSettingsProvider);
    _ctl = TextEditingController(text: s.githubClientId ?? '');
  }

  @override
  void dispose() { _ctl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('GitHub OAuth App', style: TextStyle(color: p.fg0, fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text(
          'To enable GitHub Device Flow sign-in, register an OAuth App at github.com/settings/applications/new (any callback URL works — Device Flow ignores it). Paste the Client ID below.',
          style: TextStyle(color: p.fg2, fontSize: 12),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _ctl,
          decoration: const InputDecoration(labelText: 'Client ID'),
          onChanged: (v) => ref.read(appSettingsProvider.notifier).setGithubClientId(v.isEmpty ? null : v),
        ),
        const SizedBox(height: 16),
        TextButton.icon(
          icon: const Icon(Icons.open_in_new, size: 14),
          label: const Text('Register a new OAuth App on GitHub'),
          onPressed: () => launchUrl(Uri.parse('https://github.com/settings/applications/new')),
        ),
      ]),
    );
  }
}
```

- [ ] **Step 2: Update github_device_flow.dart** — read client_id from settings

Change `_clientId` from a constant to a parameter. The caller (AuthDialog GitHub tab) passes the client_id from `appSettingsProvider`. If null, show a clear error.

```dart
class GitHubDeviceFlow {
  final String clientId;
  GitHubDeviceFlow({required this.clientId});

  Future<DeviceCodeResponse> requestDeviceCode({String scope = 'repo'}) async {
    if (clientId.isEmpty) {
      throw StateError('GitHub Client ID not configured. Settings → GitHub.');
    }
    // ... rest unchanged, but use this.clientId
  }

  Future<String> pollForToken(DeviceCodeResponse r) async {
    // use this.clientId
  }
}
```

Wire the AuthDialog GitHub tab to instantiate `GitHubDeviceFlow(clientId: settings.githubClientId ?? '')` before invoking it.

- [ ] **Step 3: Commit**

```bash
git add lib
git -c user.email=s.porta@novomatic.it -c user.name=s.porta commit -m "feat(ui): Settings → GitHub section with client_id config"
```

---

### Task B3: Authentication section (list + edit/delete/test)

**Files:**
- Modify: `lib/ui/settings/sections/authentication_section.dart`

- [ ] **Step 1: Implement**

```dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../application/git/auth_spec.dart';
import '../../../application/providers.dart';
import '../../dialogs/auth_dialog.dart';
import '../../dialogs/confirm_dialog.dart';
import '../../theme/app_palette.dart';

final _hostsProvider = FutureProvider.autoDispose<List<String>>((ref) async {
  final store = ref.watch(credentialsStoreProvider);
  return store.hosts();
});

class AuthenticationSection extends ConsumerWidget {
  const AuthenticationSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = AppPalette.of(context);
    final hosts = ref.watch(_hostsProvider);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('Saved credentials', style: TextStyle(color: p.fg0, fontSize: 14, fontWeight: FontWeight.w600)),
          const Spacer(),
          ElevatedButton.icon(
            icon: const Icon(Icons.add, size: 14),
            label: const Text('Add credential'),
            onPressed: () async {
              final host = await _promptHost(context);
              if (host == null || host.isEmpty) return;
              if (context.mounted) await AuthDialog.show(context, host);
              ref.invalidate(_hostsProvider);
            },
          ),
        ]),
        const SizedBox(height: 16),
        hosts.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Error: $e', style: TextStyle(color: p.accentErr)),
          data: (hosts) => hosts.isEmpty
              ? Text('No saved credentials.', style: TextStyle(color: p.fg2))
              : Column(children: [
                  for (final host in hosts) _HostRow(host: host, ref: ref),
                ]),
        ),
      ]),
    );
  }

  Future<String?> _promptHost(BuildContext context) async {
    final ctl = TextEditingController();
    return showDialog<String>(context: context, builder: (_) => AlertDialog(
      title: const Text('Add credential for host'),
      content: TextField(controller: ctl, decoration: const InputDecoration(hintText: 'github.com')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(onPressed: () => Navigator.pop(context, ctl.text.trim()), child: const Text('Next')),
      ],
    ));
  }
}

class _HostRow extends StatelessWidget {
  final String host;
  final WidgetRef ref;
  const _HostRow({required this.host, required this.ref});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final store = ref.read(credentialsStoreProvider);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: p.border)),
      ),
      child: Row(children: [
        Icon(Icons.key, size: 14, color: p.fg2),
        const SizedBox(width: 8),
        Expanded(child: FutureBuilder<AuthSpec?>(
          future: store.get(host),
          builder: (_, snap) {
            final kind = _kindLabel(snap.data);
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(host, style: TextStyle(color: p.fg0, fontSize: 13)),
              Text(kind, style: TextStyle(color: p.fg2, fontSize: 11)),
            ]);
          },
        )),
        TextButton(
          onPressed: () async {
            await AuthDialog.show(context, host);
            // ignore: invalid_use_of_protected_member
            // Force re-read via Riverpod invalidate is preferable but FutureBuilder above is local
            (context as Element).markNeedsBuild();
          },
          child: const Text('Edit'),
        ),
        TextButton(
          onPressed: () async {
            final ok = await ConfirmDialog.show(context,
                title: 'Delete credential', body: 'Remove saved credential for $host?',
                confirmLabel: 'Delete', dangerous: true);
            if (ok) {
              await store.delete(host);
              // ignore: use_build_context_synchronously
              (context as Element).markNeedsBuild();
            }
          },
          child: const Text('Delete'),
        ),
        TextButton(
          onPressed: () async {
            final result = await Process.run('git', ['ls-remote', 'https://$host'], runInShell: true);
            final ok = result.exitCode == 0;
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(ok ? 'OK: $host reachable' : 'Failed: ${result.stderr}'),
              ));
            }
          },
          child: const Text('Test'),
        ),
      ]),
    );
  }

  String _kindLabel(AuthSpec? s) {
    if (s == null) return '(missing)';
    return switch (s) {
      AuthHttpsPat() => 'HTTPS PAT',
      AuthHttpsBasic() => 'HTTPS Basic',
      AuthSsh() => 'SSH Key',
      AuthGitHubOauth() => 'GitHub OAuth',
      AuthSystemDefault() => 'System default',
    };
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib
git -c user.email=s.porta@novomatic.it -c user.name=s.porta commit -m "feat(ui): Settings → Authentication section (list/edit/delete/test)"
```

---

### Task B4: Make existing code consume settings (replace hard-codes)

**Files:**
- Modify: `lib/ui/working_copy/commit_compose.dart` — read commitSignoffDefault, fontSize
- Modify: `lib/ui/toolbar/git_toolbar.dart` — read defaultPullStrategy in `_pull`
- Modify: `lib/ui/conflicts/conflict_resolution_panel.dart` — read externalEditorPath for "Open in editor"

- [ ] **Step 1: CommitCompose**

In `_CommitComposeState.build`, initialise `_signOff` from `settings.commitSignoffDefault` if it's the first build:
```dart
@override
void initState() {
  super.initState();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted) return;
    final s = ref.read(appSettingsProvider);
    if (s.commitSignoffDefault) setState(() => _signOff = true);
  });
}
```

- [ ] **Step 2: GitToolbar `_pull`** — use settings

```dart
Future<void> _pull(WidgetRef ref, RepoLocation repo) {
  final strategy = switch (ref.read(appSettingsProvider).defaultPullStrategy) {
    DefaultPullStrategy.ffOnly => PullStrategy.ffOnly,
    DefaultPullStrategy.merge => PullStrategy.merge,
    DefaultPullStrategy.rebase => PullStrategy.rebase,
  };
  return _runStream(ref, OpKind.pull, 'Pulling', repo, (auth) =>
      ref.read(gitWriteOperationsProvider).pull(repo, strategy, auth: auth));
}
```

- [ ] **Step 3: ConflictResolutionPanel `_openInEditor`** — use settings path

```dart
Future<void> _openInEditor(WidgetRef ref, String repoPath, String filePath) async {
  final settingsPath = ref.read(appSettingsProvider).externalEditorPath;
  if (settingsPath != null && settingsPath.isNotEmpty) {
    final fullPath = '$repoPath/$filePath';
    await Process.run(settingsPath, [fullPath]);
  } else {
    final url = Uri.file('$repoPath/$filePath');
    await launchUrl(url);
  }
}
```

(Adjust the panel widget to be a ConsumerWidget if it isn't already.)

- [ ] **Step 4: Commit**

```bash
git add lib
git -c user.email=s.porta@novomatic.it -c user.name=s.porta commit -m "feat: wire commit/pull/conflict UI to AppSettings"
```

---

## Sub-slice 3C — Keybindings + theme switch

### Task C1: KeyCombinationCapture widget

**Files:**
- Create: `lib/ui/settings/key_combination_capture.dart`

- [ ] **Step 1: Implement**

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_palette.dart';

class KeyCombinationCapture extends StatefulWidget {
  final LogicalKeySet? initial;
  final void Function(LogicalKeySet) onCaptured;
  final VoidCallback onCancel;
  const KeyCombinationCapture({
    super.key, this.initial, required this.onCaptured, required this.onCancel,
  });

  @override
  State<KeyCombinationCapture> createState() => _State();
}

class _State extends State<KeyCombinationCapture> {
  final _focusNode = FocusNode();
  LogicalKeySet? _captured;
  String? _error;

  @override
  void initState() {
    super.initState();
    _captured = widget.initial;
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  bool _isModifier(LogicalKeyboardKey k) {
    return k == LogicalKeyboardKey.controlLeft || k == LogicalKeyboardKey.controlRight ||
           k == LogicalKeyboardKey.shiftLeft || k == LogicalKeyboardKey.shiftRight ||
           k == LogicalKeyboardKey.altLeft || k == LogicalKeyboardKey.altRight ||
           k == LogicalKeyboardKey.metaLeft || k == LogicalKeyboardKey.metaRight;
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final pressed = HardwareKeyboard.instance.logicalKeysPressed;
    final nonModifier = pressed.where((k) => !_isModifier(k)).toList();
    if (nonModifier.isEmpty) {
      setState(() => _error = 'Need at least one non-modifier key.');
      return KeyEventResult.handled;
    }
    setState(() {
      _captured = LogicalKeySet.fromSet(pressed);
      _error = null;
    });
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return AlertDialog(
      title: const Text('Press a key combination'),
      content: Focus(
        focusNode: _focusNode,
        onKeyEvent: _onKey,
        autofocus: true,
        child: Container(
          width: 320,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: p.bg2, borderRadius: BorderRadius.circular(6)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(_describe(_captured), style: TextStyle(color: p.fg0, fontSize: 16, fontFamily: 'monospace')),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: p.accentErr, fontSize: 12)),
            ],
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: widget.onCancel, child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _captured == null ? null : () => widget.onCaptured(_captured!),
          child: const Text('Save'),
        ),
      ],
    );
  }

  String _describe(LogicalKeySet? set) {
    if (set == null) return '(press keys...)';
    return set.keys.map((k) => k.keyLabel.isNotEmpty ? k.keyLabel : k.debugName ?? '?').join(' + ');
  }
}
```

- [ ] **Step 2: Commit**

```bash
& 'C:\src\flutter\bin\flutter.bat' analyze
git add lib
git -c user.email=s.porta@novomatic.it -c user.name=s.porta commit -m "feat(ui): KeyCombinationCapture widget for keybinding rebinding"
```

---

### Task C2: Keybindings section + reactive Shortcuts wiring

**Files:**
- Modify: `lib/ui/settings/sections/keybindings_section.dart`
- Modify: `lib/main.dart` — replace static Shortcuts with reactive

- [ ] **Step 1: KeybindingsSection**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../application/providers.dart';
import '../../theme/app_palette.dart';
import '../key_combination_capture.dart';

class KeybindingsSection extends ConsumerWidget {
  const KeybindingsSection({super.key});

  static const _actions = [
    ('commit', 'Commit'),
    ('commitAndPush', 'Commit & Push'),
    ('fetch', 'Fetch'),
    ('refresh', 'Refresh'),
    ('openRepoSelector', 'Open Repo Selector'),
    ('openSettings', 'Open Settings'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = AppPalette.of(context);
    final s = ref.watch(appSettingsProvider);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Keybindings', style: TextStyle(color: p.fg0, fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 16),
        for (final (id, label) in _actions)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.border))),
            child: Row(children: [
              SizedBox(width: 200, child: Text(label, style: TextStyle(color: p.fg0, fontSize: 13))),
              Expanded(child: Text(
                s.keybindings[id]?.keys.map((k) => k.keyLabel.isNotEmpty ? k.keyLabel : k.debugName ?? '?').join(' + ') ?? '(unbound)',
                style: TextStyle(color: p.fg1, fontFamily: 'monospace', fontSize: 12),
              )),
              TextButton(
                onPressed: () async {
                  final captured = await showDialog<LogicalKeySet>(
                    context: context,
                    builder: (_) => KeyCombinationCapture(
                      initial: s.keybindings[id],
                      onCaptured: (set) => Navigator.pop(context, set),
                      onCancel: () => Navigator.pop(context),
                    ),
                  );
                  if (captured != null) {
                    await ref.read(appSettingsProvider.notifier).setKeybinding(id, captured);
                  }
                },
                child: const Text('Edit'),
              ),
              TextButton(
                onPressed: () => ref.read(appSettingsProvider.notifier).resetKeybinding(id),
                child: const Text('Reset'),
              ),
            ]),
          ),
      ]),
    );
  }
}
```

- [ ] **Step 2: Reactive Shortcuts in main.dart**

Replace the existing static Shortcuts widget. The shell already has Shortcuts/Actions wiring from Slice 2 — refactor to read from `appSettingsProvider`:

```dart
class _ShellState extends ConsumerState<Shell> {
  // ... existing fields

  @override
  Widget build(BuildContext context) {
    final bindings = ref.watch(appSettingsProvider.select((s) => s.keybindings));
    return Shortcuts(
      shortcuts: {
        if (bindings['commit'] != null) bindings['commit']!: const _CommitIntent(),
        if (bindings['commitAndPush'] != null) bindings['commitAndPush']!: const _CommitAndPushIntent(),
        if (bindings['fetch'] != null) bindings['fetch']!: const _FetchIntent(),
        if (bindings['refresh'] != null) bindings['refresh']!: const _RefreshIntent(),
        if (bindings['openRepoSelector'] != null) bindings['openRepoSelector']!: const _OpenRepoSelectorIntent(),
        if (bindings['openSettings'] != null) bindings['openSettings']!: const _OpenSettingsIntent(),
      },
      child: Actions(
        actions: {
          _CommitIntent: CallbackAction<_CommitIntent>(onInvoke: (_) { /* existing */ }),
          // ... etc., plus a new _OpenSettingsIntent that toggles settingsOpenProvider
        },
        child: /* existing shell body */,
      ),
    );
  }
}
```

Add intent classes; the openSettings action toggles `settingsOpenProvider`. The other intents stay as they were.

- [ ] **Step 3: Commit**

```bash
git add lib
git -c user.email=s.porta@novomatic.it -c user.name=s.porta commit -m "feat(ui): keybindings section + reactive Shortcuts wired to settings"
```

---

### Task C3: Light theme verification

**Files:**
- (visual smoke only — no code changes)

- [ ] **Step 1: Run app and verify**

```powershell
.\run.bat
```

Settings → switch to Light → verify all panels (title bar, sidebar, commit graph, bottom panel, dialogs, toast) render correctly in light theme. Spot-check contrast ratios. If any widget still has dark-only colours, dispatch a small fix dispatch and commit `fix(ui): <widget> respects AppPalette in light theme`.

- [ ] **Step 2: If everything looks good, no commit needed; otherwise targeted fixes per widget**

---

## Sub-slice 3D — Status bar + revert

### Task D1: Revert API (TDD)

**Files:**
- Modify: `lib/application/git/merge_outcome.dart` — add RevertOutcome
- Modify: `lib/application/git/git_write_operations.dart` — add revert signatures
- Modify: `lib/infrastructure/git/git_cli_write_operations.dart` — add implementations
- Modify: `lib/application/git/repo_state_provider.dart` — add InProgressOp.revert
- Create: `test/infrastructure/git/git_cli_write_operations_revert_test.dart`

- [ ] **Step 1: Add RevertOutcome to `merge_outcome.dart`**

```dart
sealed class RevertOutcome { const RevertOutcome(); }
final class RevertApplied extends RevertOutcome {
  final CommitSha newCommit;
  const RevertApplied(this.newCommit);
}
final class RevertConflict extends RevertOutcome {
  final List<String> conflictedPaths;
  const RevertConflict(this.conflictedPaths);
}
```

- [ ] **Step 2: Add revert signatures to GitWriteOperations**

```dart
Future<GitResult<RevertOutcome>> revert(RepoLocation r, CommitSha sha);
Future<GitResult<void>> revertAbort(RepoLocation r);
Future<GitResult<CommitSha>> revertContinue(RepoLocation r);
```

- [ ] **Step 3: Failing test**

```dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitopen/application/git/git_result.dart';
import 'package:gitopen/application/git/merge_outcome.dart';
import 'package:gitopen/domain/commits/commit_sha.dart';
import 'package:gitopen/domain/repositories/repo_id.dart';
import 'package:gitopen/domain/repositories/repo_location.dart';
import 'package:gitopen/infrastructure/git/git_cli_write_operations.dart';
import '../../_helpers/repo_fixture.dart';

void main() {
  test('revert undoes a commit', () async {
    final f = await RepoFixture.withLinearHistory(2);
    try {
      final headSha = f.headSha;
      final sut = GitCliWriteOperations();
      final res = await sut.revert(RepoLocation(RepoId.newId(), f.path, 't'), CommitSha(headSha));
      expect(res, isA<GitSuccess>());
      expect((res as GitSuccess).value, isA<RevertApplied>());
      // Verify the file_1 added by the second commit is now removed
      final out = await Process.run('git', ['log', '--oneline'], workingDirectory: f.path);
      expect(out.stdout.toString(), contains('Revert'));
    } finally { await f.dispose(); }
  });
}
```

- [ ] **Step 4: Implement** in `git_cli_write_operations.dart`

```dart
@override
Future<GitResult<RevertOutcome>> revert(RepoLocation r, CommitSha sha) async {
  final result = await Process.run('git', ['revert', '--no-edit', sha.value], workingDirectory: r.path);
  final combined = '${result.stdout}\n${result.stderr}';
  if (result.exitCode == 0) {
    final head = (await _runner.run(r.path, ['rev-parse', 'HEAD'])).trim();
    return GitSuccess(RevertApplied(CommitSha(head)));
  }
  if (combined.contains('CONFLICT')) {
    final status = await _runner.run(r.path, ['diff', '--name-only', '--diff-filter=U']);
    return GitSuccess(RevertConflict(status.split('\n').where((l) => l.isNotEmpty).toList()));
  }
  return GitFailure(
    _classify(GitProcessException(['revert'], result.exitCode, result.stderr.toString())),
    result.stderr.toString(), combined,
  );
}

@override
Future<GitResult<void>> revertAbort(RepoLocation r) async {
  try { await _runner.run(r.path, ['revert', '--abort']); return const GitSuccess(null); }
  on GitProcessException catch (e) { return GitFailure(_classify(e), e.stderr, e.stderr); }
}

@override
Future<GitResult<CommitSha>> revertContinue(RepoLocation r) async {
  try {
    await _runner.run(r.path, ['revert', '--continue', '--no-edit']);
    final head = (await _runner.run(r.path, ['rev-parse', 'HEAD'])).trim();
    return GitSuccess(CommitSha(head));
  } on GitProcessException catch (e) { return GitFailure(_classify(e), e.stderr, e.stderr); }
}
```

- [ ] **Step 5: Extend InProgressOp** in `repo_state_provider.dart` — add `revert` value + probe `.git/REVERT_HEAD`

- [ ] **Step 6: Run + commit**

```bash
& 'C:\src\flutter\bin\flutter.bat' test
git add lib test
git -c user.email=s.porta@novomatic.it -c user.name=s.porta commit -m "feat(infra): revert + revertAbort + revertContinue (TDD)"
```

---

### Task D2: Conflict panel revert support + commit row menu item

**Files:**
- Modify: `lib/ui/conflicts/conflict_resolution_panel.dart`
- Modify: `lib/ui/commit_graph/commit_graph_panel.dart` — add "Revert this commit" to context menu

- [ ] **Step 1: ConflictPanel revert branch**

Extend `_abort` and `_continue` to handle `InProgressOp.revert` calling `revertAbort` / `revertContinue`. Extend the banner to say "Revert in progress" when appropriate.

- [ ] **Step 2: Commit row menu**

In `_showCommitContextMenu` add an item:
```dart
PopupMenuItem(value: 'revert', child: Text('Revert this commit')),
// in handler:
case 'revert':
  final res = await ref.read(gitWriteOperationsProvider).revert(repo, sha);
  if (res is GitFailure) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Revert failed: ${res.message}')));
  }
  ref.invalidate(commitGraphDataProvider(repo));
  ref.invalidate(repoStateProvider(repo));
  break;
```

- [ ] **Step 3: Commit**

```bash
git add lib
git -c user.email=s.porta@novomatic.it -c user.name=s.porta commit -m "feat(ui): revert in commit context menu + conflict panel integration"
```

---

### Task D3: Status bar widget

**Files:**
- Create: `lib/ui/status_bar/status_bar.dart`
- Modify: `lib/main.dart` — render StatusBar below the main panel

- [ ] **Step 1: StatusBar widget**

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/active_workspace_provider.dart';
import '../../application/git/repo_state_provider.dart';
import '../../application/operations/operations_notifier.dart';
import '../../application/operations/running_operation.dart';
import '../../application/providers.dart';
import '../theme/app_palette.dart';
import '../operations/activity_panel.dart';

class StatusBar extends ConsumerWidget {
  const StatusBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = AppPalette.of(context);
    final activeId = ref.watch(activeWorkspaceIdProvider);
    final workspaces = ref.watch(workspaceManagerProvider);
    final active = workspaces.where((w) => w.location.id == activeId).cast<dynamic>().firstOrNull;

    if (active == null) {
      return Container(height: 22, color: p.bg3);
    }
    final repo = active.location;
    final branchesAsync = ref.watch(_branchesProvider(repo));
    final inProgress = ref.watch(repoStateProvider(repo));
    final ops = ref.watch(operationsProvider);
    final running = ops.where((o) => o.status == OperationStatus.running).length;

    return Container(
      height: 22, color: p.bg3,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(children: [
        branchesAsync.when(
          loading: () => Text('loading...', style: TextStyle(color: p.fg2, fontSize: 11)),
          error: (_, __) => const SizedBox.shrink(),
          data: (b) {
            final cur = b.firstWhere((br) => br.isCurrent, orElse: () => b.first);
            return Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.fork_right, size: 11, color: p.accentCurrent),
              const SizedBox(width: 4),
              Text(cur.name, style: TextStyle(color: p.fg0, fontSize: 11)),
              if (cur.ahead > 0) Text(' ↑${cur.ahead}', style: TextStyle(color: p.accentCurrent, fontSize: 11)),
              if (cur.behind > 0) Text(' ↓${cur.behind}', style: TextStyle(color: p.accentTag, fontSize: 11)),
            ]);
          },
        ),
        const SizedBox(width: 16),
        Expanded(child: InkWell(
          onTap: () { Clipboard.setData(ClipboardData(text: repo.path)); },
          child: Text(repo.path, overflow: TextOverflow.ellipsis,
              style: TextStyle(color: p.fg2, fontSize: 11)),
        )),
        if (inProgress.value != InProgressOp.none) ...[
          Icon(Icons.warning_amber, size: 12, color: p.accentTag),
          const SizedBox(width: 4),
          Text(inProgress.value!.name, style: TextStyle(color: p.accentTag, fontSize: 11)),
          const SizedBox(width: 12),
        ],
        InkWell(
          onTap: () => showDialog(context: context, builder: (_) => const ActivityPanel()),
          child: Row(children: [
            Icon(Icons.workspaces_outline, size: 11, color: p.fg2),
            const SizedBox(width: 4),
            Text('$running op${running == 1 ? '' : 's'}', style: TextStyle(color: p.fg2, fontSize: 11)),
          ]),
        ),
      ]),
    );
  }
}

final _branchesProvider = FutureProvider.family.autoDispose<List<Branch>, RepoLocation>((ref, repo) async {
  return ref.watch(gitReadOperationsProvider).getBranches(repo);
});
```

(Add `Branch` import from domain.)

- [ ] **Step 2: Wire into Shell**

In `lib/main.dart`, place `StatusBar` below the main panel column:
```dart
// existing Column(graph + bottom)
Column(children: [
  Expanded(child: CommitGraphPanel(repo: active.location)),
  SizedBox(height: 320, child: BottomPanel(...)),
  const StatusBar(),  // ← new
]),
```

Add import.

- [ ] **Step 3: Commit**

```bash
git add lib
git -c user.email=s.porta@novomatic.it -c user.name=s.porta commit -m "feat(ui): status bar with branch + tracking + ops counter"
```

---

## Sub-slice 3E — Packaging + auto-update

### Task E1: App icon assets

**Files:**
- Create: `assets/icon/app_icon.png` (256×256, dark variant)
- Create: `assets/icon/app_icon_light.png` (256×256, light variant) — optional
- Modify: `pubspec.yaml` — declare assets

- [ ] **Step 1: Generate a placeholder icon**

If you don't have an icon, generate a simple programmatic one (256×256 PNG, dark teal `#4EC9B0` background with a white folder glyph or just the letter G). Place at `assets/icon/app_icon.png`.

- [ ] **Step 2: Declare in pubspec**

```yaml
flutter:
  uses-material-design: true
  assets:
    - assets/icon/
```

- [ ] **Step 3: Commit**

```bash
git add pubspec.yaml assets
git -c user.email=s.porta@novomatic.it -c user.name=s.porta commit -m "feat: app icon asset for packaging"
```

---

### Task E2: MSIX config

**Files:**
- Modify: `pubspec.yaml` — add `msix` dev dependency + `msix_config` section

- [ ] **Step 1: Add dev dependency**

```bash
& 'C:\src\flutter\bin\flutter.bat' pub add msix --dev
```

- [ ] **Step 2: Add `msix_config` block to pubspec.yaml**

```yaml
msix_config:
  display_name: GitOpen
  publisher_display_name: s.porta
  identity_name: com.gitopen.desktop
  msix_version: 1.0.0.0
  logo_path: assets/icon/app_icon.png
  start_menu_icon_path: assets/icon/app_icon.png
  tile_icon_path: assets/icon/app_icon.png
  install_certificate: false
  store: false
  capabilities: 'internetClient'
  output_path: build/windows/x64/runner/Release
  output_name: gitopen
```

- [ ] **Step 3: Test the build**

```powershell
Get-Process -Name gitopen -EA SilentlyContinue | Stop-Process -Force
& 'C:\src\flutter\bin\flutter.bat' build windows --release
dart run msix:create
```

Expected: `build/windows/x64/runner/Release/gitopen.msix` created.

If the MSIX tool requires a self-signed certificate for unsigned builds, set `install_certificate: false` and pass `--store false --install-certificate false` to the create command.

- [ ] **Step 4: Commit**

```bash
git add pubspec.yaml pubspec.lock
git -c user.email=s.porta@novomatic.it -c user.name=s.porta commit -m "build(win): MSIX packaging via msix package"
```

---

### Task E3: AppImage build script

**Files:**
- Create: `scripts/build-appimage.sh`
- Make executable

- [ ] **Step 1: Script**

```bash
#!/bin/bash
set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

flutter build linux --release

APP=build/AppDir
rm -rf $APP
mkdir -p $APP/usr/bin $APP/usr/share/icons/hicolor/256x256/apps $APP/usr/share/applications

cp -r build/linux/x64/release/bundle/* $APP/usr/bin/
cp assets/icon/app_icon.png $APP/usr/share/icons/hicolor/256x256/apps/gitopen.png
cp assets/icon/app_icon.png $APP/gitopen.png

cat > $APP/gitopen.desktop <<EOF
[Desktop Entry]
Name=GitOpen
Comment=Cross-platform desktop git client
Exec=gitopen
Icon=gitopen
Type=Application
Categories=Development;RevisionControl;
EOF

cp $APP/gitopen.desktop $APP/usr/share/applications/

cat > $APP/AppRun <<'EOF'
#!/bin/sh
HERE="$(dirname "$(readlink -f "${0}")")"
exec "${HERE}/usr/bin/gitopen" "$@"
EOF
chmod +x $APP/AppRun

appimagetool $APP build/GitOpen-x86_64.AppImage
```

- [ ] **Step 2: Commit**

```bash
git add scripts
chmod +x scripts/build-appimage.sh
git -c user.email=s.porta@novomatic.it -c user.name=s.porta commit -m "build(linux): AppImage build script"
```

---

### Task E4: GitHub Actions release workflow

**Files:**
- Create: `.github/workflows/release.yml`

- [ ] **Step 1: Workflow**

```yaml
name: Release
on:
  push:
    tags: ['v*.*.*']

permissions:
  contents: write

jobs:
  windows-msix:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with: { channel: stable }
      - run: flutter pub get
      - run: dart run build_runner build --delete-conflicting-outputs
      - run: flutter build windows --release
      - run: dart run msix:create
      - uses: softprops/action-gh-release@v2
        with:
          files: build/windows/x64/runner/Release/gitopen.msix
          generate_release_notes: true

  linux-appimage:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with: { channel: stable }
      - name: Install linux deps + appimagetool
        run: |
          sudo apt-get update
          sudo apt-get install -y ninja-build libgtk-3-dev liblzma-dev libstdc++-12-dev
          wget -q https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage
          chmod +x appimagetool-x86_64.AppImage
          sudo mv appimagetool-x86_64.AppImage /usr/local/bin/appimagetool
      - run: flutter pub get
      - run: dart run build_runner build --delete-conflicting-outputs
      - run: ./scripts/build-appimage.sh
      - uses: softprops/action-gh-release@v2
        with:
          files: build/GitOpen-x86_64.AppImage
          generate_release_notes: true
```

- [ ] **Step 2: Commit**

```bash
git add .github/workflows/release.yml
git -c user.email=s.porta@novomatic.it -c user.name=s.porta commit -m "ci: release workflow producing MSIX + AppImage on v*.*.* tag"
```

---

### Task E5: Velopack integration

**Files:**
- Modify: `pubspec.yaml` — add `velopack_flutter`
- Create: `lib/infrastructure/updates/velopack_updater.dart`
- Modify: `lib/main.dart` — init updater
- Modify: `lib/application/providers.dart` — updaterProvider

- [ ] **Step 1: Add package**

```bash
flutter pub add velopack_flutter
```

(Pin to latest stable.)

- [ ] **Step 2: Wrapper**

```dart
import 'package:velopack_flutter/velopack_flutter.dart';

class VelopackUpdater {
  final String updateUrl;
  bool _initialized = false;
  VelopackUpdater(this.updateUrl);

  Future<void> initialize() async {
    if (_initialized) return;
    await Velopack.run(updateUrl: updateUrl);
    _initialized = true;
  }

  Future<String?> checkForUpdates() async {
    return Velopack.checkForUpdates();
  }

  Future<void> downloadAndApplyOnRestart() async {
    await Velopack.downloadUpdates();
    await Velopack.waitExitThenApplyUpdates();
  }
}
```

(Adjust API names to the actual `velopack_flutter` package — implementer should check pub.dev for exact calls.)

- [ ] **Step 3: Provider**

```dart
final updaterProvider = Provider<VelopackUpdater>((ref) {
  return VelopackUpdater('https://github.com/s-porta/gitopen/releases/latest');
});
```

- [ ] **Step 4: Wire into main.dart**

```dart
await updater.initialize();
if (container.read(appSettingsProvider).autoUpdateCheck) {
  unawaited(_checkForUpdatesQuietly(container));
}
```

- [ ] **Step 5: Commit**

```bash
git add lib pubspec.yaml pubspec.lock
git -c user.email=s.porta@novomatic.it -c user.name=s.porta commit -m "feat(infra): Velopack auto-update integration"
```

---

### Task E6: Updates settings section

**Files:**
- Modify: `lib/ui/settings/sections/updates_section.dart`

- [ ] **Step 1: Section**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../application/providers.dart';
import '../../theme/app_palette.dart';

class UpdatesSection extends ConsumerStatefulWidget {
  const UpdatesSection({super.key});
  @override
  ConsumerState<UpdatesSection> createState() => _State();
}

class _State extends ConsumerState<UpdatesSection> {
  bool _checking = false;
  String? _status;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final s = ref.watch(appSettingsProvider);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Switch(value: s.autoUpdateCheck, onChanged: ref.read(appSettingsProvider.notifier).setAutoUpdateCheck),
          const SizedBox(width: 8),
          Text('Check for updates on startup', style: TextStyle(color: p.fg0)),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          ElevatedButton.icon(
            icon: const Icon(Icons.refresh, size: 14),
            label: const Text('Check now'),
            onPressed: _checking ? null : _check,
          ),
          const SizedBox(width: 16),
          if (_status != null) Text(_status!, style: TextStyle(color: p.fg1)),
        ]),
      ]),
    );
  }

  Future<void> _check() async {
    setState(() { _checking = true; _status = null; });
    final updater = ref.read(updaterProvider);
    try {
      final version = await updater.checkForUpdates();
      setState(() => _status = version != null ? 'Update available: $version' : 'You are up to date.');
    } catch (e) {
      setState(() => _status = 'Check failed: $e');
    } finally {
      setState(() => _checking = false);
    }
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib
git -c user.email=s.porta@novomatic.it -c user.name=s.porta commit -m "feat(ui): Settings → Updates section with auto-check + check-now"
```

---

### Task E7: README + QA + tag

**Files:**
- Modify: `README.md`
- Modify: `docs/qa-checklist.md`

- [ ] **Step 1: README section "Slice 3 features"**

Add a section listing: Settings UI, Light/Dark themes, custom keybindings, revert, status bar, MSIX/AppImage builds, auto-update. Add Windows install warning note ("SmartScreen may warn; click More info → Run anyway").

- [ ] **Step 2: QA checklist additions**

```markdown
- [ ] Switch theme to Light → all panels respect light palette
- [ ] Rebind Commit to Ctrl+S in Settings → Keybindings → shortcut works in commit textarea
- [ ] Set external editor path → trigger merge conflict → click Open → custom editor launches
- [ ] Toggle autoUpdateCheck off → no startup toast
- [ ] "Check for updates now" returns plausible result
- [ ] Right-click commit → Revert this commit → graph shows new revert commit
- [ ] Trigger revert conflict → resolve via Conflict panel → Continue
- [ ] Status bar shows current branch and ahead/behind
- [ ] Build MSIX locally → install → app launches → uninstall
- [ ] Build AppImage on Linux → ./GitOpen-x86_64.AppImage launches
```

- [ ] **Step 3: Tag**

```bash
git add README.md docs
git -c user.email=s.porta@novomatic.it -c user.name=s.porta commit -m "docs: Slice 3 README + QA checklist"
git tag -a slice-3-distribution-polish -m "Slice 3: Settings UI + themes + keybindings + packaging + auto-update + status bar + revert"
```

---

## Self-Review

**Spec coverage**:
- §2.1 AppPalette → Task A1
- §2.2 AppSettings + drift keys → Task A2
- §2.3 Velopack → Task E5
- §3 Settings page → Tasks A7 + B1-B3
- §4 Custom keybindings → Tasks C1 + C2
- §5 Packaging → Tasks E1-E4
- §6 Auto-update → Tasks E5 + E6
- §7 Status bar → Task D3
- §8 Revert → Tasks D1 + D2

**Placeholder scan**: No "TBD" / "implement later". Some sections (especially A4-A6 widget refactors, E5 velopack adapter) defer to the implementer the exact API surface to use — they reference real files / packages and provide pattern code. The implementer reads the existing code or the package docs.

**Type consistency**:
- `AppPalette`, `AppPalette.dark()`, `AppPalette.light()` consistent across A1, A3-A6
- `AppSettingsState`, `AppTheme`, `DefaultPullStrategy` consistent across A2, A3, B1, B2, B4, C2, E6
- `KeyCombinationCapture` consistent in C1, C2
- `RevertOutcome`, `RevertApplied`, `RevertConflict` consistent in D1, D2
- `InProgressOp.revert` consistent in D1, D2
- `VelopackUpdater` consistent in E5, E6

**Scope check**: 5 sub-slices, ~4-5 weeks. Plan implements the spec without expanding it.

---

## Execution

Plan saved to `docs/superpowers/plans/2026-05-12-slice3-distribution-polish.md`. Per user's standing autonomy directive ("non chiedermi piu niente"), proceed directly to subagent-driven-development without offering the choice. Skip review prompts; only stop on BLOCKED or fatal build failures.
