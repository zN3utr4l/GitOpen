# GitOpen Slice 3 — Distribution & Polish Design

- **Date:** 2026-05-12
- **Status:** Draft, pending user review
- **Author:** s.porta (with Claude Opus 4.7)
- **Builds on:** Slice 1 (2026-05-08 design spec) + Slice 2 (2026-05-12 write-ops spec)

## 1. Summary

Slice 3 turns GitOpen from a personal dev-driven tool into a polished,
distributable product. The focus is on the missing pieces that make
the app "installable, customisable, updatable":

**In scope:**
- **Settings UI** with sections: General, Authentication, Keybindings,
  GitHub, Updates, About — replaces hard-coded values throughout the
  codebase.
- **Themes**: light theme variant alongside the existing dark, refactor
  of all `Color(0xFF...)` into a centralised `AppPalette` consumed via
  Flutter's `ThemeExtension`.
- **Custom keybindings** for the 6 main app actions with a
  record-key-combo UI.
- **Packaging**: MSIX for Windows, AppImage for Linux. GitHub Actions
  release workflow producing both on tag push.
- **Auto-update** via `velopack_flutter`, pointed at the public GitHub
  Releases of the app. Toggleable in Settings.
- **Status bar**: branch + tracking info + ops counter at the bottom
  of the window.
- **Revert** (deferred from Slice 2): `git revert` via context menu
  with conflict handling reusing the existing Conflict Resolution
  panel.

**Out of scope (Slice 4+):**
- Interactive rebase (reorder / squash / edit-message)
- Submodules + LFS
- Per-repo settings overrides
- Macros / key sequence shortcuts
- Custom themes user-defined beyond light/dark
- OS-theme auto-sync (`SystemTheme.platformBrightness` listener)
- Code-signing certificate purchase + integration
- Flatpak distribution
- OAuth flow for GitLab / Bitbucket
- Auto-update silent / forced
- Rollback automatic

## 2. Architecture additions

### 2.1 Theme system

A single source of truth for colours: `lib/ui/theme/app_palette.dart`:

```dart
@immutable
final class AppPalette extends ThemeExtension<AppPalette> {
  final Color bg0;     // page bg, deepest
  final Color bg1;     // main panel
  final Color bg2;     // sidebar
  final Color bg3;     // title bar
  final Color bg4;     // hover surface
  final Color bg5;     // active surface
  final Color bgAccent;
  final Color border;
  final Color borderStrong;
  final Color fg0;     // primary text
  final Color fg1;     // secondary
  final Color fg2;     // muted
  final Color fg3;     // very muted
  final Color accentCurrent;
  final Color accentTag;
  final Color accentRemote;
  final Color accentWarn;
  final Color accentErr;
  final List<Color> lanePalette;

  const AppPalette({...});

  factory AppPalette.dark() => const AppPalette(/* current hex values */);
  factory AppPalette.light() => const AppPalette(/* light-theme values */);

  @override AppPalette copyWith({...}) => ...;
  @override AppPalette lerp(...) => ...;
}
```

Light palette draft (Fork-light-ish):

| Token | Dark (current) | Light |
|---|---|---|
| bg0 | `#1A1A1D` | `#FAFAFB` |
| bg1 | `#1F1F23` | `#FFFFFF` |
| bg2 | `#25252A` | `#F4F4F6` |
| bg3 | `#2C2C31` | `#ECECEE` |
| bg4 | `#34343A` (hover) | `#E4E4E7` |
| bg5 | `#3D3D44` (active) | `#D8D8DC` |
| bgAccent | `#094771` | `#CFE5FF` |
| border | `#313137` | `#D8D8DC` |
| fg0 | `#D4D4D4` | `#202024` |
| fg1 | `#B8B8BC` | `#414148` |
| fg2 | `#888892` | `#6E6E78` |
| fg3 | `#5D5D65` | `#9A9AA2` |
| accentCurrent | `#4EC9B0` | `#1B9E83` |
| accentTag | `#D7BA7D` | `#A87514` |
| accentRemote | `#569CD6` | `#2A6BB1` |
| accentWarn | `#CE9178` | `#A0552C` |
| accentErr | `#F48771` | `#B92C2C` |
| lanePalette | dark teal/yellow/blue/orange/purple/blue/orange/red | desaturated equivalents |

All existing widgets — TitleBar, RepoSelector, TabsBar (legacy), Sidebar,
CommitGraphPanel, CommitRow, RefPill, BottomPanel, DiffView,
FileTreeView, WorkingCopyPanel, ConflictResolutionPanel, ToastOverlay,
ActivityPanel, AuthDialog, CloneDialog, WelcomeScreen — get refactored
to read from `Theme.of(context).extension<AppPalette>()!` instead of
inline hex. Many existing `const Color(0xFF...)` become non-const reads
of the palette inside `build`.

### 2.2 Settings storage

The existing drift `settings` table (key + valueJson) is reused. New
keys:

| Key | Type | Default |
|---|---|---|
| `theme` | `"dark" \| "light"` | `"dark"` |
| `external_editor_path` | `string?` | `null` |
| `default_pull_strategy` | `"ff-only" \| "merge" \| "rebase"` | `"merge"` |
| `commit_signoff_default` | `bool` | `false` |
| `font_size` | `int` | `12` |
| `font_family` | `string` | system default |
| `github_client_id` | `string?` | `null` |
| `auto_update_check` | `bool` | `true` |
| `keybindings` | JSON map `<action, keyCombo>` | built-ins |

A new `AppSettings` Riverpod `StateNotifier<AppSettingsState>` loads all
keys at startup, exposes typed getters, persists every mutation. Other
parts of the app already-watching `appSettingsProvider` rebuild
automatically.

### 2.3 Velopack integration

`velopack_flutter` is the Flutter-side facade over the Velopack
cross-platform updater. On app startup, after `runApp`:

```dart
final updater = VelopackUpdater(
  updateUrl: 'https://github.com/<user>/gitopen/releases/latest',
);
await updater.initialize();
// if Settings.autoUpdateCheck is true:
unawaited(updater.checkForUpdates().then((available) {
  if (available) showUpdateToast(available);
}));
```

User clicks toast → updater downloads delta → next launch applies. No
forced restart.

## 3. Settings page

### 3.1 Surface

A dedicated `SettingsPage` widget replaces the main right-panel
content (where commit graph + bottom panel live) when
`settingsOpenProvider` is true. Triggered by:
- ⚙ icon in the title bar (right of window controls? No — left of
  them, between the right MoveWindow spacer and the controls)
- Configurable shortcut (default `Ctrl+,`)

### 3.2 Layout

Two-column: left navigation list, right detail pane.

```
Settings
├─ General       (selected)
├─ Authentication
├─ Keybindings
├─ GitHub
├─ Updates
└─ About

[Right pane content for the selected section]
```

### 3.3 Sections

**General**
- Theme: radio (Dark / Light)
- Font size: numeric stepper (10–18)
- Font family: dropdown (System / JetBrains Mono / Cascadia / Inter)
- External editor: text field + Browse… (path picker), info text "leave
  empty to fall back to $VISUAL → $EDITOR → heuristic detection"
- Default pull strategy: dropdown (Merge / Rebase / Fast-forward only)
- Sign-off commits by default: checkbox

**Authentication**
- Lists every entry in `CredentialsStore.hosts()` with host + auth
  kind. Per row: [Edit] (opens `AuthDialog` pre-filled), [Delete]
  (with confirm), [Test] (runs `git ls-remote https://<host>` and
  shows OK / Failure).
- Footer button "Add credential…" opens `AuthDialog` for a chosen
  host.

**Keybindings**
- Table: Action | Current binding | [Edit] [Reset]
- Edit → modal "Press a key combination..." captures the next press
  via a focus-trapping widget; rejects only-modifiers, validates no
  collision, saves to `settings.keybindings`.
- Reset → restores default for that action.
- Reset all → restores all defaults.

**GitHub**
- Client ID text field with explanatory link to
  https://github.com/settings/applications/new and copy-paste flow.

**Updates**
- Auto-check for updates on startup: checkbox
- "Check for updates now" button — runs
  `updater.checkForUpdates()`, shows result inline
- Current version + commit SHA display

**About**
- App name, version, license (MIT), link to GitHub repo, list of major
  dependencies + their licenses.

## 4. Custom keybindings

### 4.1 Action registry

```dart
enum AppAction {
  commit,
  commitAndPush,
  fetch,
  refresh,
  openRepoSelector,
  openSettings,
}

final defaultBindings = <AppAction, LogicalKeySet>{
  AppAction.commit: LogicalKeySet(
      LogicalKeyboardKey.controlLeft, LogicalKeyboardKey.enter),
  AppAction.commitAndPush: LogicalKeySet(
      LogicalKeyboardKey.controlLeft, LogicalKeyboardKey.shiftLeft, LogicalKeyboardKey.enter),
  AppAction.fetch: LogicalKeySet(LogicalKeyboardKey.f5),
  AppAction.refresh: LogicalKeySet(
      LogicalKeyboardKey.controlLeft, LogicalKeyboardKey.keyR),
  AppAction.openRepoSelector: LogicalKeySet(
      LogicalKeyboardKey.controlLeft, LogicalKeyboardKey.keyT),
  AppAction.openSettings: LogicalKeySet(
      LogicalKeyboardKey.controlLeft, LogicalKeyboardKey.comma),
};
```

### 4.2 Wiring

Replace the current `Shortcuts({...})` block in `main.dart` with a
reactive one that reads from `appSettingsProvider`:

```dart
Consumer(
  builder: (context, ref, child) {
    final bindings = ref.watch(appSettingsProvider.select((s) => s.keybindings));
    return Shortcuts(
      shortcuts: {
        for (final entry in bindings.entries)
          entry.value: _intentForAction(entry.key),
      },
      child: child!,
    );
  },
  child: Actions(
    actions: {/* AppAction → Action */},
    child: const Shell(),
  ),
)
```

### 4.3 Capture UI

`KeyCombinationCapture` widget:
- Auto-focuses on open
- Listens via `RawKeyboardListener` (or `Focus(onKeyEvent: ...)`)
- Builds a `LogicalKeySet` from the latest non-modifier-only press
- Validates: at least one non-modifier, not already bound to a
  different action
- Cancel / OK / Reset buttons

## 5. Packaging

### 5.1 MSIX (Windows)

`pubspec.yaml`:
```yaml
dev_dependencies:
  msix: ^3.16.0

msix_config:
  display_name: GitOpen
  publisher_display_name: s.porta
  identity_name: com.gitopen.desktop
  msix_version: 1.0.0.0
  logo_path: assets\icon\app_icon.png
  start_menu_icon_path: assets\icon\app_icon.png
  tile_icon_path: assets\icon\app_icon.png
  install_certificate: false
  store: false
  capabilities: 'internetClient'
  app_uri_handler_hosts: 'github.com'
```

Build:
```
flutter build windows --release
dart run msix:create
```

Produces `build/windows/x64/runner/Release/gitopen.msix`. Double-click
to install per-user. SmartScreen warns; user clicks "More info → Run
anyway". Documented in README.

### 5.2 AppImage (Linux)

A standalone script `scripts/build-appimage.sh`:

```bash
#!/bin/bash
set -e
flutter build linux --release
APP=build/AppDir
mkdir -p $APP/usr/bin $APP/usr/lib $APP/usr/share/icons/hicolor/256x256/apps
cp -r build/linux/x64/release/bundle/* $APP/usr/bin/
cp assets/icon/app_icon.png $APP/usr/share/icons/hicolor/256x256/apps/gitopen.png
cat > $APP/gitopen.desktop <<EOF
[Desktop Entry]
Name=GitOpen
Exec=gitopen
Icon=gitopen
Type=Application
Categories=Development;RevisionControl;
EOF
cat > $APP/AppRun <<'EOF'
#!/bin/sh
HERE="$(dirname "$(readlink -f "${0}")")"
exec "${HERE}/usr/bin/gitopen" "$@"
EOF
chmod +x $APP/AppRun
appimagetool $APP build/GitOpen-x86_64.AppImage
```

Requires `appimagetool` available on PATH (CI installs it; documented
in README for local builds).

### 5.3 GitHub Actions release workflow

`.github/workflows/release.yml`:

```yaml
name: Release
on:
  push:
    tags: ['v*.*.*']

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

  linux-appimage:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with: { channel: stable }
      - name: Install linux deps
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
```

A separate `Release` job draft generates `body` from `git log
<previous-tag>..HEAD --oneline`.

### 5.4 Versioning

`pubspec.yaml` `version:` follows SemVer `X.Y.Z+buildNumber`. Tagging
`vX.Y.Z` triggers the release workflow. The build number is updated
automatically on each tag via a `.github/workflows/bump-version.yml`
that runs `dart pub run build_runner build` first.

## 6. Auto-update

### 6.1 Velopack integration

`pubspec.yaml`:
```yaml
dependencies:
  velopack_flutter: ^0.1.x  # latest stable
```

Init in `main.dart`:
```dart
late final VelopackUpdater updater;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  updater = VelopackUpdater(
    updateUrl: 'https://github.com/<owner>/gitopen',
  );
  await updater.initialize();

  // existing ProviderContainer + runApp + window setup
  if (ref.read(appSettingsProvider).autoUpdateCheck) {
    unawaited(_checkForUpdatesQuietly());
  }
}

Future<void> _checkForUpdatesQuietly() async {
  final available = await updater.checkForUpdates();
  if (available != null) {
    // emit a soft toast via operationsProvider with action "Install"
  }
}
```

A new `updaterProvider` exposes the Velopack instance and current
state. Settings → Updates section consumes it.

### 6.2 Update flow

1. App starts → `updater.checkForUpdates()` (if Settings allow).
2. If newer release found → soft toast "Update 1.2.4 available
   — Install on next launch?" with `[Install]` button.
3. User clicks Install → `updater.downloadUpdates()` (background) →
   `updater.applyUpdatesAndRestart()` (or queue for restart). The
   first call is non-blocking with progress in activity panel.
4. On the user's choice, app exits and re-launches updated.

Manual: Settings → "Check for updates now" button runs the same
flow.

## 7. Status bar

A new widget `lib/ui/status_bar/status_bar.dart` sits at the
bottom of the Shell, below the existing
CommitGraphPanel + (Working Copy | Bottom Panel | Conflict Panel)
column.

Three regions:

```
┌───────────────────────────────────────────────────────────────┐
│ [⎇ master] ↑3 ↓1 │ /home/.../novomatic-game-services │ 2 ops ⚙│
└───────────────────────────────────────────────────────────────┘
```

- **Left**: branch icon + name + tracking deltas. Click → opens the
  same Branch dropdown that the toolbar exposes.
- **Centre**: repo path, ellipsised. Click → copies path to
  clipboard.
- **Right**: ops counter (number of running RunningOperations). Click
  → opens activity panel. ⚠ icon if conflict in-progress (links to
  conflict panel). Heights: 22 px row, smaller font (11 px).

Data: watches `repoStatusProvider`, `gitReadOperationsProvider.getBranches`
(for tracking deltas via current branch's ahead/behind), `operationsProvider`,
`repoStateProvider`.

## 8. Revert

### 8.1 API

```dart
// In GitWriteOperations
Future<GitResult<RevertOutcome>> revert(RepoLocation r, CommitSha sha);
Future<GitResult<void>> revertAbort(RepoLocation r);
Future<GitResult<CommitSha>> revertContinue(RepoLocation r);

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

### 8.2 Implementation

```dart
@override
Future<GitResult<RevertOutcome>> revert(RepoLocation r, CommitSha sha) async {
  final result = await Process.run('git', ['revert', '--no-edit', sha.value], workingDirectory: r.path);
  if (result.exitCode == 0) {
    final head = (await _runner.run(r.path, ['rev-parse', 'HEAD'])).trim();
    return GitSuccess(RevertApplied(CommitSha(head)));
  }
  final combined = '${result.stdout}\n${result.stderr}';
  if (combined.contains('CONFLICT')) {
    final status = await _runner.run(r.path, ['diff', '--name-only', '--diff-filter=U']);
    return GitSuccess(RevertConflict(status.split('\n').where((l) => l.isNotEmpty).toList()));
  }
  return GitFailure(_classify(GitProcessException(['revert'], result.exitCode, result.stderr.toString())),
      result.stderr.toString(), combined);
}
```

### 8.3 UI

- Add `InProgressOp.revert` enum value (probe `.git/REVERT_HEAD`).
- Extend `ConflictResolutionPanel` to handle revert mode (banner text,
  Continue/Abort wired to `revertContinue` / `revertAbort`).
- Commit row context menu: add `Revert this commit` item.

## 9. Phasing

Five sub-slices, ~4-5 weeks total:

1. **3A — Theme + Settings foundation** (~1 week)
   - Extract `AppPalette` ThemeExtension
   - Refactor all widgets to read palette from theme
   - Build `AppSettings` StateNotifier + drift schema additions
   - Build empty `SettingsPage` shell with navigation list + section
     stubs
   - Add ⚙ icon trigger + `Ctrl+,` default binding

2. **3B — Settings content** (~1 week)
   - Implement General / GitHub / About sections wiring against
     `appSettingsProvider`
   - Implement Authentication section (list / edit / delete / test)
   - Make existing code consume settings instead of hard-coded values
     (external editor path, GitHub client_id, default pull strategy,
     sign-off default, font)

3. **3C — Keybindings + theme switch** (~0.5 week)
   - Action registry + default bindings
   - Reactive Shortcuts widget reading settings
   - KeyCombinationCapture widget
   - Keybindings settings section
   - Light theme palette + switch wiring

4. **3D — Status bar + revert** (~0.5 week)
   - StatusBar widget
   - Revert API + implementation (TDD)
   - Conflict panel extension for revert
   - Commit row context menu item

5. **3E — Packaging + auto-update** (~2 weeks)
   - MSIX config in pubspec, app icon assets, manifest tweaking
   - AppImage build script + manifest
   - Velopack integration + updaterProvider
   - Updates settings section
   - GitHub Actions release workflow
   - First end-to-end release: tag `v0.3.0`, verify both artefacts
     produced

## 10. Testing strategy

### 10.1 Unit + infrastructure

- `AppSettings`: load / save / migration tests against in-memory drift
- `revert` op: 2 TDD tests (clean revert; conflict)
- `KeyCombinationCapture`: widget test for capture + validation

Target: +15 new tests on top of the Slice 2 baseline of 67 → ~82
total.

### 10.2 Manual QA

`docs/qa-checklist.md` additions:
- Settings → switch theme → all panels respect new colours
- Settings → rebind Commit to Ctrl+S → shortcut works
- Settings → set external editor to VS Code → mid-merge Open opens
  VS Code
- Settings → toggle auto-update off → no toast on startup
- Settings → "Check for updates now" → result inline
- Revert a commit → graph shows new revert commit
- Trigger revert conflict → resolve via Conflict panel → Continue
- Status bar shows current branch + ahead/behind
- MSIX install on Windows test machine
- AppImage on Ubuntu test box

### 10.3 CI

The release workflow is itself the smoke test for packaging — failing
builds fail the release.

## 11. Risks and mitigations

| Risk | Mitigation |
|---|---|
| `velopack_flutter` package immature on Flutter Desktop | Pin a known-good version; isolate behind `updaterProvider` so we can swap to a different mechanism (manual download check via `http`) without touching UI |
| MSIX install warns SmartScreen on first run | Document workaround in README; revisit code-signing in a later slice |
| ThemeExtension refactor touches every UI file | Do it in one PR; rely on `flutter analyze` to catch missed call-sites; pre-existing tests cover behaviour |
| Custom keybinding capture might miss modifier-only edge case | Validate in `KeyCombinationCapture.onKeyEvent` — reject if zero non-modifier keys |
| GitHub Actions runners change Flutter SDK version | Pin `flutter-action` channel: stable; use `flutter --version` in workflow to log the actual version |
| AppImage misses a dynamic library | Linux runner uses `linuxdeploy --plugin gtk` if needed; document any missing-deps fix |

## 12. Open questions for the plan

- Exact `velopack_flutter` package version (latest stable at plan
  time)
- AppImage icon source size (256×256 PNG)
- Whether to bundle a manual rollback script in case auto-update
  bricks a user — deferred unless requested
