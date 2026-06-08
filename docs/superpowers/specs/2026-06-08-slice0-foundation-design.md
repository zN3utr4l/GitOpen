# Slice 0 — Fondamenta del fork

**Date:** 2026-06-08
**Status:** draft (in review)
**Slice:** GitOpen — fork stabilization & hygiene
**Owner:** zN3utr4l (fork di `samuu98/GitOpen`)

## Contesto

`zN3utr4l` riprende GitOpen (client git desktop Flutter/Dart, Windows+Linux,
architettura `domain`/`application`/`infrastructure`/`ui`, operazioni git via
CLI) con l'obiettivo a lungo termine di portarlo a **parità funzionale con
Fork/GitKraken**. La parità è una maratona da affrontare in slice indipendenti.

Questo è lo **Slice 0**: non aggiunge feature. Mette in piedi un fork stabile,
"proprio" e con base sana, su cui ogni slice successivo sarà più veloce e
sicuro da costruire.

## Problema

1. Il fork non esiste ancora: serve setup repo + CI sul nuovo account, senza
   violare la licenza MIT del progetto originale.
2. Due bug noti minano la fiducia nella base:
   - **Diff dei merge commit vuoto.** `getDiff` usa `git show <sha> --raw -p`.
     Per un commit di merge git produce un *combined diff* con header `@@@ … @@@`;
     il parser riconosce solo `@@ … @@`, quindi il file compare senza hunk →
     diff vuoto.
   - **Classificazione errori locale-dipendente.** `GitCliWriteOperations._classify`
     fa match su sottostringhe inglesi dello stderr (`permission denied`,
     `non-fast-forward`, `could not resolve`, …). Su un PC con git in locale non
     inglese la categorizzazione (auth/network/conflict/…) salta.
3. Igiene del codice: i lint attuali sono il set base `flutter_lints`.

## Scope

### In
- **Fork & identità**
  - Fork `samuu98/GitOpen` → `zN3utr4l/GitOpen`.
  - `LICENSE` invariato (resta `Copyright (c) 2026 s.porta`); si aggiunge una
    riga/clausola di copyright per zN3utr4l mantenendo la nota MIT originale.
  - README: sezione "Fork mantenuto da zN3utr4l" (nome tecnico resta "GitOpen").
  - About section (`lib/ui/settings/sections/about_section.dart`): indicare fork
    e manutentore.
  - Auto-updater e workflow di release ripuntati sul repo `zN3utr4l/GitOpen`
    (l'updater non deve interrogare le release del repo originale).
- **CI propria**
  - Abilitare GitHub Actions sul fork; `ci.yml` (analyze + test) verde.
  - `release.yml` adattato a tag/repo del fork.
- **Bug 1 — diff dei merge commit**
  - Per i commit con >1 genitore, mostrare il diff **rispetto al primo genitore**
    (default di Fork/GitKraken). Combined diff completo = fuori scope (slice futuro).
- **Bug 2 — errori locale-dipendenti**
  - Forzare `LC_ALL=C` (e `LANG=C`) nell'environment dei processi git, così lo
    stderr è sempre in inglese e `_classify` è deterministico.
- **Igiene lint**
  - Adottare il set `very_good_analysis`; cleanup del codice guidato **solo** da
    ciò che i lint segnalano (nessun refactor discrezionale).

### Out (esplicito)
- Qualsiasi feature nuova (rebase interattivo, merge editor, blame, ricerca,
  reflog, submodule, syntax highlighting, GPG): slice successivi.
- Ottimizzazioni di performance: nessun problema misurato; il codice è già
  streaming/timeout-aware. YAGNI.
- Refactor architetturali non richiesti dai lint.
- Rebrand del nome del prodotto.
- Rendering del combined diff dei merge.

## Architettura / interventi

### Bug 1 — diff merge vs primo genitore
`lib/infrastructure/git/git_cli_read_operations.dart` → `getDiff`, caso
`DiffSpecCommitVsParent`.

Approccio: rilevare se `commitSha` è un merge (più di un genitore) e, in tal
caso, costruire il diff a 2 vie contro il primo genitore — ad es.
`git show -m --first-parent <sha> --format= --raw -p --no-color`, oppure
`git diff <sha>^1 <sha> --raw -p --no-color`. La forma esatta dei flag va
**confermata in fase di riproduzione** (vedi Test). Il parser unificato
esistente resta invariato perché riceverà un diff `@@` normale.

> Nota: il numero di genitori può essere ricavato con
> `git rev-list --parents -n 1 <sha>` o è già noto al grafo via `CommitInfo.parentShas`.

### Bug 2 — locale forzato
`lib/infrastructure/git/git_process_runner.dart` (e qualunque punto che fa
`Process.start`/`Process.run` di git: anche `git_cli_write_operations.dart` usa
`Process.start`/`Process.run` direttamente per progress/merge/rebase/cherry-pick).
Iniettare nell'environment `LC_ALL=C`, `LANG=C` in modo centralizzato, così
**tutti** i percorsi git ereditano lo stesso locale. Verificare che i punti che
oggi passano `environment:` custom (credential helper) facciano merge con il
locale invece di sovrascriverlo.

### Identità / fork
- `LICENSE`: append nota copyright zN3utr4l.
- `README.md`: sezione fork.
- `about_section.dart`: stringa manutentore/fork.
- Updater: individuare il riferimento al repo (`github_release_updater.dart`)
  e puntarlo a `zN3utr4l/GitOpen`.
- `release.yml`: repo/owner del fork.

### Lint
- `pubspec.yaml` dev_dependencies: aggiungere `very_good_analysis`.
- `analysis_options.yaml`: `include: package:very_good_analysis/analysis_options.yaml`.
- Eseguire `dart fix --apply` per i fix meccanici; risolvere a mano il residuo.

## Test (TDD — rigido sui bug)

Per **ogni** bug, prima un test che fallisce, poi il fix:
- **Bug 1**: in `test/infrastructure/git/git_cli_read_operations_diff_test.dart`
  (o file affine), tramite `repo_fixture`, creare un repo con un branch, un
  merge commit, e asserire che `getDiff(DiffSpecCommitVsParent(mergeSha))`
  restituisce hunk non vuoti per i file cambiati dal merge. Il test rosso
  conferma anche la forma reale dell'output git da gestire.
- **Bug 2**: test su `_classify`/mappatura errori che simuli stderr in un altro
  locale (o asserisca che l'environment git contiene `LC_ALL=C`), verificando
  che la categoria resti corretta.

Chiusura slice: `flutter analyze` (0 issue col nuovo set) e `flutter test`
(tutti verdi) in locale **e** in CI sul fork.

## Sequenza (alto livello)
1. Conferma account `zN3utr4l` → fork → set remote (`origin`=fork,
   `upstream`=samuu98) → abilita Actions.
2. Bug 1: test rosso → fix → verde.
3. Bug 2: test rosso → fix → verde.
4. Identità (LICENSE/README/About/updater/release).
5. Lint very_good_analysis → `dart fix --apply` → cleanup residuo → analyze verde.
6. CI verde sul fork; tag/release di smoke se serve.

## Rischi
- **Durata lint**: `very_good_analysis` può emettere molte segnalazioni;
  mitigazione = `dart fix --apply` + fix a batch. Se il volume è eccessivo,
  decidere in corsa se disattivare puntualmente alcune regole troppo rumorose.
- **Forma diff merge**: i flag esatti dipendono dal comportamento reale di git;
  per questo si riproduce con test prima di fissare l'implementazione.
- **Fork = azione pubblica**: eseguito solo dopo approvazione, previa riconferma
  dell'account `zN3utr4l`.

## Criteri di accettazione
- Repo `zN3utr4l/GitOpen` esiste, CI verde, LICENSE conforme MIT (copyright
  originale preservato + nota zN3utr4l).
- Selezionando un merge commit nel grafo, il diff mostra i cambiamenti vs primo
  genitore (non più vuoto), con test a copertura.
- Classificazione errori corretta a prescindere dal locale di sistema, con test.
- `flutter analyze` pulito col set very_good_analysis e `flutter test` verde.
