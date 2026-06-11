import 'package:flutter/material.dart';
import 'package:gitopen/domain/repositories/repo_location.dart';

/// GitHub PRs/Actions view - full implementation lands with the panel task.
class GitHubPanel extends StatelessWidget {
  const GitHubPanel({required this.repo, super.key});
  final RepoLocation repo;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
