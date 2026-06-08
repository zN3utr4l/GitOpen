import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gitopen/domain/commits/commit_sha.dart';
import 'package:gitopen/domain/repositories/repo_id.dart';

final activeWorkspaceIdProvider = StateProvider<RepoId?>((_) => null);
final selectedCommitShaProvider = StateProvider<CommitSha?>((_) => null);

/// Incrementing counter — CommitCompose watches this and triggers a commit
/// whenever the value changes (i.e. on each Ctrl+Enter key event).
final triggerCommitProvider = StateProvider<int>((_) => 0);
