import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'commit_graph/commit_graph_layout.dart';
import 'git/git_read_operations.dart';
import 'workspaces/repository_registry.dart';
import 'workspaces/workspace.dart';
import 'workspaces/workspace_manager.dart';
import 'workspaces/workspace_persistence.dart';
import '../infrastructure/git/git_cli_read_operations.dart';
import '../infrastructure/git/git_process_runner.dart';
import '../infrastructure/persistence/database.dart';
import '../infrastructure/persistence/repository_registry_impl.dart';
import '../infrastructure/persistence/workspace_persistence_impl.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final gitProcessRunnerProvider = Provider<GitProcessRunner>((ref) {
  return GitProcessRunner();
});

final gitReadOperationsProvider = Provider<GitReadOperations>((ref) {
  return GitCliReadOperations(runner: ref.watch(gitProcessRunnerProvider));
});

final repositoryRegistryProvider = Provider<RepositoryRegistry>((ref) {
  return DriftRepositoryRegistry(ref.watch(appDatabaseProvider));
});

final workspacePersistenceProvider = Provider<WorkspacePersistence>((ref) {
  return DriftWorkspacePersistence(ref.watch(appDatabaseProvider));
});

final commitGraphLayoutProvider = Provider<CommitGraphLayout>((ref) {
  return const DefaultCommitGraphLayout();
});

final workspaceManagerProvider =
    StateNotifierProvider<WorkspaceManager, List<Workspace>>((ref) {
  return WorkspaceManager(ref.watch(repositoryRegistryProvider));
});
