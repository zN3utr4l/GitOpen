import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gitopen/domain/repositories/repo_location.dart';
import 'package:path/path.dart' as p;

enum InProgressOp { none, merge, cherryPick, rebase, revert }

final AutoDisposeFutureProviderFamily<InProgressOp, RepoLocation>
    repoStateProvider =
    FutureProvider.family.autoDispose<InProgressOp, RepoLocation>(
        (ref, repo) async {
  bool fileExists(String name) =>
      File(p.join(repo.path, '.git', name)).existsSync();
  bool dirExists(String name) =>
      Directory(p.join(repo.path, '.git', name)).existsSync();
  if (fileExists('MERGE_HEAD')) return InProgressOp.merge;
  if (fileExists('CHERRY_PICK_HEAD')) return InProgressOp.cherryPick;
  // `git rebase` creates one of these dirs while paused on a conflict;
  // REBASE_HEAD alone is unreliable (set by interactive rebase only).
  if (dirExists('rebase-merge') || dirExists('rebase-apply')) {
    return InProgressOp.rebase;
  }
  if (fileExists('REVERT_HEAD')) return InProgressOp.revert;
  return InProgressOp.none;
});
