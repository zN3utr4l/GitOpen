# Phase 4 — S5 Stash Preview, Undo Commit, GPG Badge, A11y Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans or superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close the remaining high-value UI/UX items before widget-test hardening: stash preview + selected-file stash, explicit undo-last-commit, GPG signature badge in commit details, and accessibility semantics for graph/working-copy rows.

**Branch:** `feat/phase4-s5-stash-undo-a11y` from `origin/main` after S4. Version -> `0.1.17+18`.

**Verification:** targeted tests after each backend block; final `flutter test -j 2`, `flutter analyze`, `git diff --check`.

## Tasks

- [x] **Task 1: Stash read/write support**
  - Add `GitReadOperations.getStashDiff(repo, index)` and implement it with `git stash show --raw -p --no-color stash@{index}` through the existing diff parser.
  - Extend `stashSave` through write interface, CLI writer, service, and controller with optional `paths` so `git stash push -m <message> -- <paths...>` can stash a selected file.
  - Tests: real-git stash diff parsing and partial stash path scoping; service fake coverage for path forwarding.

- [x] **Task 2: Stash UI**
  - Update toolbar stash menu with "Stash selected file..." when a working-copy file is selected and unstaged.
  - Replace the simple stash list dialog with a split list/preview dialog that loads and renders a stash diff, keeping Apply/Pop/Drop actions available.
  - Add context-menu "Stash file..." to unstaged working-copy rows.

- [x] **Task 3: Undo last commit**
  - Add an explicit "Undo last commit (soft reset)..." context action only on the current HEAD commit when it has a parent.
  - Confirm the action and call existing `reset(repo, parent, ResetMode.soft)`.

- [x] **Task 4: GPG signature badge**
  - Add a compact signature-status value to `CommitInfo`, parsed from git log `%G?`.
  - Show a badge in commit details for signed, invalid, missing-key, and unsigned states.
  - Tests: domain equality and log parsing default/known states.

- [x] **Task 5: A11y pass**
  - Add semantics labels/selection state to graph commit rows and local-changes row.
  - Add semantics labels/selection state to working-copy file rows and useful labels for line/hunk controls.

- [x] **Task 6: Finalize**
  - Bump `pubspec.yaml` to `0.1.17+18`.
  - Run full verification, push, open PR, merge on green.
