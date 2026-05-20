import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../../domain/repositories/repo_location.dart';

enum InProgressOp { none, merge, cherryPick, rebase, revert }

final repoStateProvider =
    FutureProvider.family.autoDispose<InProgressOp, RepoLocation>(
        (ref, repo) async {
  Future<bool> fileExists(String name) =>
      File(p.join(repo.path, '.git', name)).exists();
  Future<bool> dirExists(String name) =>
      Directory(p.join(repo.path, '.git', name)).exists();
  if (await fileExists('MERGE_HEAD')) return InProgressOp.merge;
  if (await fileExists('CHERRY_PICK_HEAD')) return InProgressOp.cherryPick;
  // `git rebase` creates one of these dirs while paused on a conflict;
  // REBASE_HEAD alone is unreliable (set by interactive rebase only).
  if (await dirExists('rebase-merge') || await dirExists('rebase-apply')) {
    return InProgressOp.rebase;
  }
  if (await fileExists('REVERT_HEAD')) return InProgressOp.revert;
  return InProgressOp.none;
});
