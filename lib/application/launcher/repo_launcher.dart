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
