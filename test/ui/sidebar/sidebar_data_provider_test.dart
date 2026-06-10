import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitopen/application/git/git_read_operations.dart';
import 'package:gitopen/application/providers.dart';
import 'package:gitopen/domain/refs/branch.dart';
import 'package:gitopen/domain/refs/remote.dart';
import 'package:gitopen/domain/refs/stash.dart';
import 'package:gitopen/domain/refs/submodule.dart';
import 'package:gitopen/domain/refs/tag.dart';
import 'package:gitopen/domain/refs/worktree.dart';
import 'package:gitopen/domain/repositories/repo_id.dart';
import 'package:gitopen/domain/repositories/repo_location.dart';
import 'package:gitopen/ui/sidebar/sidebar_shared.dart';

class _FakeRead implements GitReadOperations {
  static const _branch = Branch(
    name: 'master',
    fullName: 'refs/heads/master',
    isRemote: false,
    isCurrent: true,
    ahead: 0,
    behind: 0,
  );

  @override
  Future<List<Branch>> getLocalBranches(RepoLocation repo) async => [_branch];
  @override
  Future<List<Branch>> getRemoteBranches(RepoLocation repo) async => [];
  @override
  Future<List<Branch>> getBranches(RepoLocation repo) async => [_branch];
  @override
  Future<List<Tag>> getTags(RepoLocation repo) async => [];
  @override
  Future<List<Remote>> getRemotes(RepoLocation repo) async => [];
  @override
  Future<List<Stash>> getStashes(RepoLocation repo) async => [];
  @override
  Future<List<Submodule>> getSubmodules(RepoLocation repo) async => [];
  @override
  Future<List<Worktree>> getWorktrees(RepoLocation repo) async => [];
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not faked');
}

void main() {
  test('sidebarDataProvider loads all six sections', () async {
    final container = ProviderContainer(overrides: [
      gitReadOperationsProvider.overrideWithValue(_FakeRead()),
    ]);
    addTearDown(container.dispose);
    final repo = RepoLocation(RepoId.newId(), 'unused', 't');
    final data = await container.read(sidebarDataProvider(repo).future);
    expect(data.branches, hasLength(1));
    expect(data.tags, isEmpty);
    expect(data.remotes, isEmpty);
    expect(data.stashes, isEmpty);
    expect(data.submodules, isEmpty);
    expect(data.worktrees, isEmpty);
  });
}
