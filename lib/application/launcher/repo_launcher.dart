import 'package:flutter/foundation.dart';
import 'package:gitopen/domain/repositories/repo_location.dart';

@immutable
class EditorTarget {
  const EditorTarget({
    required this.id,
    required this.displayName,
    required this.executable,
  });
  final String id;
  final String displayName;
  final String executable;

  @override
  bool operator ==(Object other) => other is EditorTarget && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'EditorTarget($displayName)';
}

class LauncherException implements Exception {
  const LauncherException(this.message);
  final String message;
  @override
  String toString() => message;
}

abstract interface class RepoLauncher {
  Future<void> revealInFiles(RepoLocation repo);
  Future<void> openInTerminal(RepoLocation repo);
  Future<void> openInEditor(RepoLocation repo, EditorTarget editor);
  Future<List<EditorTarget>> detectAvailableEditors();
}
