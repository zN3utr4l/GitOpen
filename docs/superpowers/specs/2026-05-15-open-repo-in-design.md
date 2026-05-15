# Open current repo in… (files / terminal / editor)

**Date:** 2026-05-15
**Status:** approved
**Slice:** GitOpen — quick-launch dropdown

## Problem

Manca un modo rapido per saltare dal repo attivo in GitOpen agli strumenti esterni che l'utente usa per lavorarci: file manager di sistema, terminale e editor. Oggi bisogna copiare il path e aprire manualmente.

## Scope

In:
- Toolbar dropdown "Open" accanto a Branch/Stash.
- Tre azioni: *Show in file explorer*, *Open in terminal*, *Open in <editor>*.
- Auto-detection multi-editor (VS Code sempre incluso se presente; rilevati anche Cursor, IntelliJ/Rider/WebStorm, Sublime, Android Studio, Fleet — se installati e nel PATH). Se nessun editor è rilevato, il menu mostra solo "Open in VS Code" che, se VS Code non c'è, segnala l'errore via SnackBar.
- Supporto Windows / macOS / Linux (Windows è la piattaforma primaria di sviluppo).

Out:
- Context-menu da repo del workspace sidebar (slice futura — il dropdown copre già l'use-case principale).
- Pannello settings per override dei comandi (YAGNI).
- Sub-azioni "open file in editor", "open at specific commit".
- Detection di terminali custom (Windows Terminal / Powershell / cmd in fallback automatico, niente preferenza utente).

## Architettura

Coerente col pattern `application` (interfaccia) → `infrastructure` (impl) → Riverpod provider.

### Domain / application

`lib/application/launcher/repo_launcher.dart` — interfaccia:

```dart
abstract interface class RepoLauncher {
  Future<void> revealInFiles(RepoLocation repo);
  Future<void> openInTerminal(RepoLocation repo);
  Future<void> openInEditor(RepoLocation repo, EditorTarget editor);

  /// Probes the system once and caches the result for the session.
  Future<List<EditorTarget>> detectAvailableEditors();
}

class EditorTarget {
  final String id;           // 'vscode', 'cursor', 'idea', ...
  final String displayName;  // 'VS Code', 'Cursor', 'IntelliJ IDEA'
  final String executable;   // resolved absolute path or bare command
  const EditorTarget({...});
}

class LauncherException implements Exception {
  final String message;
  const LauncherException(this.message);
}
```

### Infrastructure

`lib/infrastructure/launcher/system_repo_launcher.dart` — implementa `RepoLauncher` usando `Process.start` (detached, `mode: ProcessStartMode.detached`).

**Tabella comandi:**

| Azione    | Windows                                      | macOS                                                  | Linux                                                                 |
|-----------|----------------------------------------------|--------------------------------------------------------|-----------------------------------------------------------------------|
| Files     | `explorer.exe <path>`                        | `open <path>`                                          | `xdg-open <path>`                                                     |
| Terminal  | `wt.exe -d <path>` → fallback `powershell -NoExit -WorkingDirectory <path>` → `cmd /K cd /D <path>` | `open -a Terminal <path>`                              | `gnome-terminal --working-directory=<path>` → `konsole --workdir <path>` → `xterm` |
| Editor    | `<executable> <path>`                        | `<executable> <path>` (con fallback `open -a <appName> <path>` se serve) | `<executable> <path>`                                                |

Fallback chain: il primo comando della catena che si avvia con exit-code 0 (o detached senza errore di spawn) vince. Catena = lista di `List<String>` provata in ordine.

**Detection editor — Windows:**

Per ciascun editor noto provo `where <command-name>` (eseguibile sincrono, breve timeout). Se restituisce un path → editor disponibile. Comandi probe:

| Editor          | Command name(s)                       |
|-----------------|----------------------------------------|
| VS Code         | `code`, `code.cmd`                     |
| Cursor          | `cursor`, `cursor.cmd`                 |
| IntelliJ IDEA   | `idea`, `idea64`                       |
| WebStorm        | `webstorm`, `webstorm64`               |
| Rider           | `rider`, `rider64`                     |
| Sublime Text    | `subl`                                 |
| Android Studio  | `studio`, `studio64`                   |
| Fleet           | `fleet`                                |

**Detection editor — macOS / Linux:** stesso elenco, con `which <command-name>`.

Il risultato della detection è cachato per la sessione (`Future<List<EditorTarget>>` memoizzato nel provider).

### Provider

`lib/application/providers.dart`:

```dart
final repoLauncherProvider = Provider<RepoLauncher>(
  (ref) => SystemRepoLauncher(),
);

final availableEditorsProvider = FutureProvider<List<EditorTarget>>((ref) {
  return ref.read(repoLauncherProvider).detectAvailableEditors();
});
```

### UI

`lib/ui/toolbar/git_toolbar.dart` — aggiunto un nuovo `_OpenDropdown` accanto a `_StashDropdown`:

```
[Fetch] [Pull] [Push]   [Branch ▾] [Stash ▾] [Open ▾]
```

Voci del menu (in ordine):
1. `Show in file explorer`         (`Icons.folder_open`)
2. `Open in terminal`              (`Icons.terminal`)
3. *Divider*
4. Per ogni editor rilevato: `Open in <displayName>` (`Icons.code` per editor "code-like", `Icons.architecture` per IDE JetBrains; semplificazione: tutti `Icons.code` ok)
5. Se nessun editor rilevato: una sola voce `Open in VS Code` che proverà comunque `code` e segnalerà errore se assente.

Errori → `ScaffoldMessenger.of(context).showSnackBar(...)` con messaggio chiaro (es. *"VS Code not found in PATH"*, *"No terminal application available"*).

## Data flow

```
GitToolbar (_OpenDropdown)
  └─ ref.read(repoLauncherProvider).openInEditor(repo, editor)
        └─ SystemRepoLauncher
              └─ Process.start(executable, [path], mode: detached)
```

Nessun side effect su stato Git, niente da invalidare. Solo errori sono riportati alla UI tramite eccezione → SnackBar.

## Error handling

- `Process.start` può lanciare `ProcessException` se l'eseguibile non si trova: catturato e ritradotto in `LauncherException` con messaggio user-facing.
- Per le catene di fallback (terminal Windows/Linux), si itera finché uno funziona; se *tutti* falliscono → `LauncherException("No terminal application available — install Windows Terminal or check PATH")`.
- `LauncherException` viene catturata in UI e mostrata come SnackBar; non logghiamo stack trace all'utente.

## Testing

- **Unit test** `test/launcher/system_repo_launcher_test.dart`: testa solo la *risoluzione* dei comandi e la catena di fallback usando un `ProcessRunner` injectable (analogo al pattern di `GitProcessRunner`). Niente test di esecuzione vera.
- **Test UI** `test/ui/toolbar/open_dropdown_test.dart` con un fake `RepoLauncher` che traccia le chiamate: verifica che il menu mostri solo gli editor presenti e che ogni voce chiami il metodo giusto.
- **Verifica manuale**: dopo l'implementazione, lancio l'app, attivo un repo e provo tutte e tre le azioni su Windows.

## Spec self-review

- Nessun placeholder/TODO.
- Scope a singolo slice (UI + launcher + detection) — fattibile in un piano.
- "code-like vs JetBrains" icona è ambigua → ho semplificato a "tutti `Icons.code` ok".
- Catena fallback terminale Windows: `wt.exe` può essere installato ma non in PATH di default; comunque `where wt` lo trova quando è dal Microsoft Store. Accettato il rischio.
