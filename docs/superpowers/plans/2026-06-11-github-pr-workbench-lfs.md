# GitHub PR Workbench + Git LFS Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a GitHub-only pull-request workbench and a Git LFS daily-driver view to GitOpen.

**Architecture:** Extend the existing `GitHubApi`/`GitHubRestApi` port and keep all GitHub PR operations behind that interface. Add a dedicated Git LFS application port and CLI infrastructure adapter, then expose both features through focused Riverpod providers and split UI widgets instead of growing the current monolithic GitHub panel.

**Tech Stack:** Flutter, Riverpod, Dart `http`, existing Git CLI infrastructure, Git LFS CLI, `flutter_test`, `http/testing`, temporary real Git repositories.

---

## Scope

This is one branch and one product slice because the requested delivery is "all together", but it is still implemented as small, testable commits. GitHub PRs and Git LFS remain separate modules so either area can be debugged independently.

## File Structure

GitHub application and infrastructure:

- Modify `lib/application/github/github_models.dart`: add full PR detail, file, review, comment, issue-comment, request, merge, and review-submit models.
- Modify `lib/application/github/github_api.dart`: add PR read/mutation methods and extend `GitHubApiErrorKind`.
- Modify `lib/infrastructure/github/github_rest_api.dart`: add HTTP verbs, endpoint mapping, response parsing, status mapping, and optional ready-for-review GraphQL fallback.
- Create `lib/application/github/github_pr_diff.dart`: parse GitHub patch text into commentable diff lines and map UI line choices to GitHub review-comment coordinates.

GitHub UI:

- Modify `lib/ui/github/github_panel.dart`: keep only composition, slug/profile/token gating, and tabs.
- Create `lib/ui/github/github_providers.dart`: provider families for PR detail, files, reviews, review comments, issue comments, checks, and runs.
- Create `lib/ui/github/github_api_state.dart`: sign-in CTA and typed API error state widgets.
- Create `lib/ui/github/github_tabs_bar.dart`: tab row reused by GitHub workbench.
- Create `lib/ui/github/actions_tab.dart`: move existing Actions tab into a focused file.
- Create `lib/ui/github/pull_requests_tab.dart`: split PR list/detail workbench.
- Create `lib/ui/github/pull_request_detail_view.dart`: PR header, body, state chips, and top-level actions.
- Create `lib/ui/github/pull_request_files_view.dart`: PR file list, patch rendering, inline comment affordances.
- Create `lib/ui/github/pull_request_forms.dart`: create/edit/merge dialogs.
- Create `lib/ui/github/pull_request_review_drawer.dart`: queued review body, line comments, submit actions, and replies.

Git LFS application and infrastructure:

- Create `lib/application/git_lfs/git_lfs_models.dart`: `GitLfsStatus`, `GitLfsTrackedPattern`, `GitLfsFile`.
- Create `lib/application/git_lfs/git_lfs_operations.dart`: LFS port.
- Create `lib/application/git_lfs/git_lfs_service.dart`: progress/auth orchestration for LFS sync and simple LFS mutations.
- Create `lib/infrastructure/git_lfs/git_lfs_parsers.dart`: pure parser helpers.
- Create `lib/infrastructure/git_lfs/git_cli_lfs_operations.dart`: Git LFS CLI adapter.
- Modify `lib/application/providers.dart`: wire `gitLfsOperationsProvider`, `gitLfsServiceProvider`, and LFS read providers.

Shared UI support and LFS UI:

- Create `lib/ui/git/git_action_bridges.dart`: public UI bridges for auth prompts and operation progress, extracted from private classes in `git_actions_controller.dart`.
- Modify `lib/ui/git/git_actions_controller.dart`: use the shared bridge classes.
- Create `lib/ui/lfs/lfs_actions_controller.dart`: UI entry point for install/track/untrack/fetch/pull/push.
- Create `lib/ui/lfs/lfs_panel.dart`: LFS status, setup, tracked patterns, files, and sync actions.
- Modify `lib/application/main_view_provider.dart`: add `MainView.lfs`.
- Modify `lib/ui/shell/view_selector.dart`: add always-visible `LFS` segment.
- Modify `lib/main.dart`: route `MainView.lfs` to `LfsPanel`.

Tests:

- Modify `test/infrastructure/github/github_rest_api_test.dart`.
- Create `test/application/github/github_pr_diff_test.dart`.
- Modify `test/ui/github/github_panel_test.dart`.
- Create `test/application/git_lfs/git_lfs_service_test.dart`.
- Create `test/infrastructure/git_lfs/git_lfs_parsers_test.dart`.
- Create `test/infrastructure/git_lfs/git_cli_lfs_operations_test.dart`.
- Create `test/ui/lfs/lfs_panel_test.dart`.
- Modify `test/application/providers_test.dart`.

---

### Task 1: GitHub PR Models, API, and REST Mapping

**Files:**
- Modify: `lib/application/github/github_models.dart`
- Modify: `lib/application/github/github_api.dart`
- Modify: `lib/infrastructure/github/github_rest_api.dart`
- Test: `test/infrastructure/github/github_rest_api_test.dart`

- [ ] **Step 1: Write failing REST tests for new PR endpoints**

Add a `group('pull request details and mutations', () { ... })` to `test/infrastructure/github/github_rest_api_test.dart` with these tests:

```dart
test('getPullRequest parses detail fields', () async {
  final client = MockClient((request) async {
    expect(request.method, 'GET');
    expect(request.url.path, '/repos/o/r/pulls/7');
    return http.Response(jsonEncode(_detailJson()), 200);
  });

  final detail = await _api(client).getPullRequest(_slug, 7, token: 'tok');

  expect(detail.number, 7);
  expect(detail.nodeId, 'PR_kwDOExample');
  expect(detail.title, 'Add thing');
  expect(detail.body, 'Body text');
  expect(detail.author, 'ada');
  expect(detail.state, 'open');
  expect(detail.isDraft, isTrue);
  expect(detail.mergeable, isTrue);
  expect(detail.mergeStateStatus, 'clean');
  expect(detail.baseRef, 'main');
  expect(detail.headRef, 'feat/x');
  expect(detail.headSha, 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa');
});

test('listPullRequestFiles parses file patches', () async {
  final client = MockClient((request) async {
    expect(request.url.path, '/repos/o/r/pulls/7/files');
    return http.Response(
      jsonEncode([
        {
          'filename': 'lib/app.dart',
          'status': 'modified',
          'additions': 2,
          'deletions': 1,
          'changes': 3,
          'patch': '@@ -1,2 +1,3 @@\n old\n+new\n same',
        },
      ]),
      200,
    );
  });

  final files = await _api(client).listPullRequestFiles(_slug, 7, token: 't');

  expect(files.single.filename, 'lib/app.dart');
  expect(files.single.patch, contains('+new'));
});

test('createPullRequest posts the expected body', () async {
  late Map<String, dynamic> body;
  final client = MockClient((request) async {
    expect(request.method, 'POST');
    expect(request.url.path, '/repos/o/r/pulls');
    body = jsonDecode(request.body) as Map<String, dynamic>;
    return http.Response(jsonEncode(_detailJson(number: 8)), 201);
  });

  final created = await _api(client).createPullRequest(
    _slug,
    const CreatePullRequestRequest(
      title: 'New PR',
      body: 'Ready',
      head: 'feat/x',
      base: 'main',
      draft: true,
    ),
    token: 'tok',
  );

  expect(body, {
    'title': 'New PR',
    'body': 'Ready',
    'head': 'feat/x',
    'base': 'main',
    'draft': true,
  });
  expect(created.number, 8);
});

test('mergePullRequest maps blocked merge responses', () async {
  final client = MockClient((request) async {
    expect(request.method, 'PUT');
    expect(request.url.path, '/repos/o/r/pulls/7/merge');
    return http.Response(jsonEncode({'message': 'Pull Request is not mergeable'}), 405);
  });

  await expectLater(
    _api(client).mergePullRequest(
      _slug,
      7,
      const MergePullRequestRequest(method: PullRequestMergeMethod.squash),
      token: 'tok',
    ),
    throwsA(
      isA<GitHubApiException>().having(
        (e) => e.kind,
        'kind',
        GitHubApiErrorKind.mergeBlocked,
      ),
    ),
  );
});
```

Add helper JSON in the same test file:

```dart
Map<String, dynamic> _detailJson({int number = 7}) => {
  'node_id': 'PR_kwDOExample',
  'number': number,
  'title': 'Add thing',
  'body': 'Body text',
  'state': 'open',
  'draft': true,
  'mergeable': true,
  'mergeable_state': 'clean',
  'html_url': 'https://github.com/o/r/pull/$number',
  'created_at': '2026-06-11T09:00:00Z',
  'updated_at': '2026-06-11T10:00:00Z',
  'user': {'login': 'ada'},
  'base': {'ref': 'main'},
  'head': {'ref': 'feat/x', 'sha': 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'},
};
```

- [ ] **Step 2: Run the failing REST tests**

Run: `flutter test test/infrastructure/github/github_rest_api_test.dart -j 1`

Expected: FAIL with undefined methods and types such as `getPullRequest`, `CreatePullRequestRequest`, and `PullRequestMergeMethod`.

- [ ] **Step 3: Add GitHub models**

Append the new models to `lib/application/github/github_models.dart` after `WorkflowRunInfo`:

```dart
enum PullRequestMergeMethod { merge, squash, rebase }

final class PullRequestDetail extends Equatable {
  const PullRequestDetail({
    required this.number,
    required this.nodeId,
    required this.title,
    required this.body,
    required this.author,
    required this.state,
    required this.isDraft,
    required this.mergeable,
    required this.mergeStateStatus,
    required this.baseRef,
    required this.headRef,
    required this.headSha,
    required this.htmlUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  final int number;
  final String nodeId;
  final String title;
  final String body;
  final String author;
  final String state;
  final bool isDraft;
  final bool? mergeable;
  final String mergeStateStatus;
  final String baseRef;
  final String headRef;
  final String headSha;
  final String htmlUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isOpen => state == 'open';

  @override
  List<Object?> get props => [
    number,
    nodeId,
    title,
    body,
    author,
    state,
    isDraft,
    mergeable,
    mergeStateStatus,
    baseRef,
    headRef,
    headSha,
    htmlUrl,
    createdAt,
    updatedAt,
  ];
}

final class PullRequestFile extends Equatable {
  const PullRequestFile({
    required this.filename,
    required this.status,
    required this.additions,
    required this.deletions,
    required this.changes,
    required this.patch,
  });

  final String filename;
  final String status;
  final int additions;
  final int deletions;
  final int changes;
  final String patch;

  @override
  List<Object?> get props => [
    filename,
    status,
    additions,
    deletions,
    changes,
    patch,
  ];
}

final class PullRequestReview extends Equatable {
  const PullRequestReview({
    required this.id,
    required this.user,
    required this.state,
    required this.body,
    required this.submittedAt,
    required this.htmlUrl,
  });

  final int id;
  final String user;
  final String state;
  final String body;
  final DateTime? submittedAt;
  final String htmlUrl;

  @override
  List<Object?> get props => [id, user, state, body, submittedAt, htmlUrl];
}

final class PullRequestComment extends Equatable {
  const PullRequestComment({
    required this.id,
    required this.user,
    required this.body,
    required this.path,
    required this.side,
    required this.line,
    required this.position,
    required this.inReplyToId,
    required this.createdAt,
    required this.updatedAt,
    required this.htmlUrl,
  });

  final int id;
  final String user;
  final String body;
  final String path;
  final String side;
  final int? line;
  final int? position;
  final int? inReplyToId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String htmlUrl;

  @override
  List<Object?> get props => [
    id,
    user,
    body,
    path,
    side,
    line,
    position,
    inReplyToId,
    createdAt,
    updatedAt,
    htmlUrl,
  ];
}

final class IssueCommentInfo extends Equatable {
  const IssueCommentInfo({
    required this.id,
    required this.user,
    required this.body,
    required this.createdAt,
    required this.updatedAt,
    required this.htmlUrl,
  });

  final int id;
  final String user;
  final String body;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String htmlUrl;

  @override
  List<Object?> get props => [id, user, body, createdAt, updatedAt, htmlUrl];
}

final class CreatePullRequestRequest extends Equatable {
  const CreatePullRequestRequest({
    required this.title,
    required this.body,
    required this.head,
    required this.base,
    required this.draft,
  });

  final String title;
  final String body;
  final String head;
  final String base;
  final bool draft;

  Map<String, Object?> toJson() => {
    'title': title,
    'body': body,
    'head': head,
    'base': base,
    'draft': draft,
  };

  @override
  List<Object?> get props => [title, body, head, base, draft];
}

final class UpdatePullRequestRequest extends Equatable {
  const UpdatePullRequestRequest({
    this.title,
    this.body,
    this.state,
    this.base,
    this.maintainerCanModify,
  });

  final String? title;
  final String? body;
  final String? state;
  final String? base;
  final bool? maintainerCanModify;

  Map<String, Object?> toJson() => {
    if (title != null) 'title': title,
    if (body != null) 'body': body,
    if (state != null) 'state': state,
    if (base != null) 'base': base,
    if (maintainerCanModify != null)
      'maintainer_can_modify': maintainerCanModify,
  };

  @override
  List<Object?> get props => [title, body, state, base, maintainerCanModify];
}

final class DraftReviewComment extends Equatable {
  const DraftReviewComment({
    required this.path,
    required this.body,
    required this.line,
    required this.side,
  });

  final String path;
  final String body;
  final int line;
  final String side;

  Map<String, Object?> toJson() => {
    'path': path,
    'body': body,
    'line': line,
    'side': side,
  };

  @override
  List<Object?> get props => [path, body, line, side];
}

final class SubmitReviewRequest extends Equatable {
  const SubmitReviewRequest({
    required this.event,
    required this.body,
    required this.comments,
  });

  final String event;
  final String body;
  final List<DraftReviewComment> comments;

  Map<String, Object?> toJson() => {
    'event': event,
    'body': body,
    if (comments.isNotEmpty)
      'comments': [for (final c in comments) c.toJson()],
  };

  @override
  List<Object?> get props => [event, body, comments];
}

final class MergePullRequestRequest extends Equatable {
  const MergePullRequestRequest({
    required this.method,
    this.commitTitle,
    this.commitMessage,
  });

  final PullRequestMergeMethod method;
  final String? commitTitle;
  final String? commitMessage;

  Map<String, Object?> toJson() => {
    'merge_method': method.name,
    if (commitTitle != null && commitTitle!.isNotEmpty)
      'commit_title': commitTitle,
    if (commitMessage != null && commitMessage!.isNotEmpty)
      'commit_message': commitMessage,
  };

  @override
  List<Object?> get props => [method, commitTitle, commitMessage];
}
```

- [ ] **Step 4: Extend the GitHub API port**

Update `lib/application/github/github_api.dart`:

```dart
enum GitHubApiErrorKind {
  auth,
  rateLimit,
  network,
  notFound,
  validation,
  conflict,
  mergeBlocked,
}
```

Add these abstract methods to `GitHubApi`:

```dart
Future<PullRequestDetail> getPullRequest(
  RepoSlug slug,
  int number, {
  required String token,
});

Future<List<PullRequestFile>> listPullRequestFiles(
  RepoSlug slug,
  int number, {
  required String token,
});

Future<List<PullRequestReview>> listPullRequestReviews(
  RepoSlug slug,
  int number, {
  required String token,
});

Future<List<PullRequestComment>> listPullRequestReviewComments(
  RepoSlug slug,
  int number, {
  required String token,
});

Future<List<IssueCommentInfo>> listPullRequestIssueComments(
  RepoSlug slug,
  int number, {
  required String token,
});

Future<PullRequestDetail> createPullRequest(
  RepoSlug slug,
  CreatePullRequestRequest request, {
  required String token,
});

Future<PullRequestDetail> updatePullRequest(
  RepoSlug slug,
  int number,
  UpdatePullRequestRequest request, {
  required String token,
});

Future<PullRequestDetail> markPullRequestReadyForReview(
  RepoSlug slug,
  int number, {
  required String token,
});

Future<void> mergePullRequest(
  RepoSlug slug,
  int number,
  MergePullRequestRequest request, {
  required String token,
});

Future<IssueCommentInfo> createIssueComment(
  RepoSlug slug,
  int number,
  String body, {
  required String token,
});

Future<PullRequestReview> createReview(
  RepoSlug slug,
  int number,
  SubmitReviewRequest request, {
  required String token,
});

Future<PullRequestComment> createReviewCommentReply(
  RepoSlug slug,
  int number,
  int commentId,
  String body, {
  required String token,
});
```

- [ ] **Step 5: Implement REST verbs, GraphQL helper, and parsers**

In `lib/infrastructure/github/github_rest_api.dart`, add `_post`, `_patch`, and `_put` helpers that share status mapping with `_get`:

```dart
Future<dynamic> _post(
  String path,
  String token, {
  Object? body,
  Map<String, String> query = const {},
}) =>
    _request('POST', path, token, body: body, query: query);

Future<dynamic> _patch(String path, String token, {Object? body}) =>
    _request('PATCH', path, token, body: body);

Future<dynamic> _put(String path, String token, {Object? body}) =>
    _request('PUT', path, token, body: body);
```

Refactor `_get` to call:

```dart
Future<dynamic> _request(
  String method,
  String path,
  String token, {
  Object? body,
  Map<String, String> query = const {},
}) async {
  final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
  final headers = {
    'Accept': 'application/vnd.github+json',
    'Authorization': 'Bearer $token',
    'X-GitHub-Api-Version': '2022-11-28',
    if (body != null) 'Content-Type': 'application/json',
  };
  final encodedBody = body == null ? null : jsonEncode(body);
  late final http.Response response;
  try {
    response = switch (method) {
      'GET' => await _client.get(uri, headers: headers),
      'POST' => await _client.post(uri, headers: headers, body: encodedBody),
      'PATCH' => await _client.patch(uri, headers: headers, body: encodedBody),
      'PUT' => await _client.put(uri, headers: headers, body: encodedBody),
      _ => throw StateError('Unsupported HTTP method $method'),
    };
  } on http.ClientException catch (e) {
    throw GitHubApiException(GitHubApiErrorKind.network, e.message);
  } on SocketException catch (e) {
    throw GitHubApiException(GitHubApiErrorKind.network, e.message);
  }
  return _decodeResponse(response);
}
```

Add status handling:

```dart
dynamic _decodeResponse(http.Response response) {
  if (response.statusCode >= 200 && response.statusCode < 300) {
    if (response.body.trim().isEmpty) return null;
    return jsonDecode(response.body);
  }
  final message = _messageOf(response);
  switch (response.statusCode) {
    case 401:
      throw const GitHubApiException(
        GitHubApiErrorKind.auth,
        'GitHub rejected the credential (401). Sign in again.',
      );
    case 403 || 429:
      if (response.headers['x-ratelimit-remaining'] == '0') {
        throw const GitHubApiException(
          GitHubApiErrorKind.rateLimit,
          'GitHub API rate limit reached. Try again later.',
        );
      }
      throw GitHubApiException(GitHubApiErrorKind.auth, message);
    case 404:
      throw const GitHubApiException(
        GitHubApiErrorKind.notFound,
        'Not found on GitHub (404).',
      );
    case 405:
      throw GitHubApiException(GitHubApiErrorKind.mergeBlocked, message);
    case 409:
      throw GitHubApiException(GitHubApiErrorKind.conflict, message);
    case 422:
      throw GitHubApiException(GitHubApiErrorKind.validation, message);
    default:
      throw GitHubApiException(
        GitHubApiErrorKind.network,
        'GitHub API returned ${response.statusCode}.',
      );
  }
}

String _messageOf(http.Response response) {
  try {
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return decoded['message'] as String? ??
        'GitHub API returned ${response.statusCode}.';
  } on Object {
    return 'GitHub API returned ${response.statusCode}.';
  }
}
```

Add a narrow GraphQL helper only for ready-for-review:

```dart
Future<dynamic> _graphql(
  String token, {
  required String query,
  required Map<String, Object?> variables,
}) {
  return _request(
    'POST',
    '/graphql',
    token,
    body: {'query': query, 'variables': variables},
  );
}
```

Implement endpoint methods using `_parsePullRequestDetail`, `_parsePullRequestFile`, `_parseReview`, `_parseReviewComment`, and `_parseIssueComment`.

`markPullRequestReadyForReview` must use the PR `nodeId` because GitHub exposes this operation as GraphQL:

```dart
@override
Future<PullRequestDetail> markPullRequestReadyForReview(
  RepoSlug slug,
  int number, {
  required String token,
}) async {
  final detail = await getPullRequest(slug, number, token: token);
  await _graphql(
    token,
    query: r'''
mutation MarkReady($id: ID!) {
  markPullRequestReadyForReview(input: {pullRequestId: $id}) {
    pullRequest { id }
  }
}
''',
    variables: {'id': detail.nodeId},
  );
  return getPullRequest(slug, number, token: token);
}
```

`_parsePullRequestDetail` reads `node_id` into `PullRequestDetail.nodeId`.

- [ ] **Step 6: Run and commit Task 1**

Run:

```powershell
flutter test test/infrastructure/github/github_rest_api_test.dart -j 1
dart format lib/application/github lib/infrastructure/github test/infrastructure/github
flutter analyze
```

Expected: tests pass; analyze reports no new issues.

Commit:

```powershell
git add lib/application/github lib/infrastructure/github test/infrastructure/github/github_rest_api_test.dart
git commit -m "feat: add GitHub PR REST operations"
```

---

### Task 2: GitHub Patch Line Mapping

**Files:**
- Create: `lib/application/github/github_pr_diff.dart`
- Test: `test/application/github/github_pr_diff_test.dart`

- [ ] **Step 1: Write failing parser tests**

Create `test/application/github/github_pr_diff_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:gitopen/application/github/github_pr_diff.dart';

void main() {
  test('parseGitHubPatch maps added and context lines', () {
    const patch = '@@ -1,2 +1,3 @@\n old\n+new\n same';

    final lines = parseGitHubPatch(patch);

    expect(lines, hasLength(3));
    expect(lines[0].oldLine, 1);
    expect(lines[0].newLine, 1);
    expect(lines[0].side, 'RIGHT');
    expect(lines[1].oldLine, isNull);
    expect(lines[1].newLine, 2);
    expect(lines[1].side, 'RIGHT');
    expect(lines[1].isCommentable, isTrue);
  });

  test('parseGitHubPatch maps deleted lines to LEFT side', () {
    const patch = '@@ -4,2 +4,1 @@\n keep\n-delete me';

    final deleted = parseGitHubPatch(patch).last;

    expect(deleted.oldLine, 5);
    expect(deleted.newLine, isNull);
    expect(deleted.side, 'LEFT');
    expect(deleted.commentLine, 5);
  });

  test('parseGitHubPatch supports multiple hunks', () {
    const patch = '@@ -1 +1 @@\n-a\n+b\n@@ -10 +10 @@\n c';

    final lines = parseGitHubPatch(patch);

    expect(lines.map((l) => l.content), ['-a', '+b', ' c']);
    expect(lines.last.oldLine, 10);
    expect(lines.last.newLine, 10);
  });
}
```

- [ ] **Step 2: Run parser tests to verify failure**

Run: `flutter test test/application/github/github_pr_diff_test.dart -j 1`

Expected: FAIL because `github_pr_diff.dart` does not exist.

- [ ] **Step 3: Implement patch parsing**

Create `lib/application/github/github_pr_diff.dart`:

```dart
final class GitHubPatchLine {
  const GitHubPatchLine({
    required this.content,
    required this.oldLine,
    required this.newLine,
  });

  final String content;
  final int? oldLine;
  final int? newLine;

  bool get isAddition => content.startsWith('+');
  bool get isDeletion => content.startsWith('-');
  bool get isContext => content.startsWith(' ');
  bool get isCommentable => isAddition || isDeletion || isContext;
  String get side => isDeletion ? 'LEFT' : 'RIGHT';
  int? get commentLine => isDeletion ? oldLine : newLine;
}

final _hunkHeader = RegExp(r'^@@ -(\d+)(?:,\d+)? \+(\d+)(?:,\d+)? @@');

List<GitHubPatchLine> parseGitHubPatch(String patch) {
  final result = <GitHubPatchLine>[];
  var oldLine = 0;
  var newLine = 0;
  for (final raw in patch.split('\n')) {
    final hunk = _hunkHeader.firstMatch(raw);
    if (hunk != null) {
      oldLine = int.parse(hunk.group(1)!);
      newLine = int.parse(hunk.group(2)!);
      continue;
    }
    if (raw.isEmpty || raw.startsWith(r'\')) continue;
    if (raw.startsWith('+')) {
      result.add(GitHubPatchLine(content: raw, oldLine: null, newLine: newLine));
      newLine++;
      continue;
    }
    if (raw.startsWith('-')) {
      result.add(GitHubPatchLine(content: raw, oldLine: oldLine, newLine: null));
      oldLine++;
      continue;
    }
    result.add(
      GitHubPatchLine(content: raw, oldLine: oldLine, newLine: newLine),
    );
    oldLine++;
    newLine++;
  }
  return result;
}
```

- [ ] **Step 4: Run and commit Task 2**

Run:

```powershell
flutter test test/application/github/github_pr_diff_test.dart -j 1
dart format lib/application/github/github_pr_diff.dart test/application/github/github_pr_diff_test.dart
```

Expected: PASS.

Commit:

```powershell
git add lib/application/github/github_pr_diff.dart test/application/github/github_pr_diff_test.dart
git commit -m "feat: parse GitHub PR patch lines"
```

---

### Task 3: GitHub Workbench Read-Only UI

**Files:**
- Modify: `lib/ui/github/github_panel.dart`
- Create: `lib/ui/github/github_providers.dart`
- Create: `lib/ui/github/github_api_state.dart`
- Create: `lib/ui/github/github_tabs_bar.dart`
- Create: `lib/ui/github/actions_tab.dart`
- Create: `lib/ui/github/pull_requests_tab.dart`
- Create: `lib/ui/github/pull_request_detail_view.dart`
- Create: `lib/ui/github/pull_request_files_view.dart`
- Modify: `test/ui/github/github_panel_test.dart`

- [ ] **Step 1: Extend the fake API and write failing UI tests**

In `test/ui/github/github_panel_test.dart`, implement every new `GitHubApi` method on `_FakeApi`. Return deterministic data:

```dart
@override
Future<PullRequestDetail> getPullRequest(
  RepoSlug slug,
  int number, {
  required String token,
}) async =>
    PullRequestDetail(
      number: number,
      nodeId: 'PR_kwDOExample',
      title: 'Improve the widget',
      body: 'Detailed body',
      author: 'ada',
      state: 'open',
      isDraft: true,
      mergeable: true,
      mergeStateStatus: 'clean',
      baseRef: 'main',
      headRef: 'feat/widget',
      headSha: 'a' * 40,
      htmlUrl: 'https://github.com/o/r/pull/$number',
      createdAt: DateTime.utc(2026, 6, 10),
      updatedAt: DateTime.utc(2026, 6, 11),
    );

@override
Future<List<PullRequestFile>> listPullRequestFiles(
  RepoSlug slug,
  int number, {
  required String token,
}) async =>
    const [
      PullRequestFile(
        filename: 'lib/widget.dart',
        status: 'modified',
        additions: 2,
        deletions: 1,
        changes: 3,
        patch: '@@ -1 +1,2 @@\n-old\n+new\n+line',
      ),
    ];
```

Add this widget test:

```dart
testWidgets('selecting a PR shows detail and changed files', (tester) async {
  await _pump(tester, repo: repo, api: _FakeApi(), profile: profile);

  await tester.tap(find.text('Improve the widget'));
  await tester.pumpAndSettle();

  expect(find.text('Detailed body'), findsOneWidget);
  expect(find.text('main <- feat/widget'), findsOneWidget);
  expect(find.text('lib/widget.dart'), findsOneWidget);
  expect(find.textContaining('+new'), findsOneWidget);
});
```

- [ ] **Step 2: Run UI test to verify failure**

Run: `flutter test test/ui/github/github_panel_test.dart -j 1`

Expected: FAIL because the current tab only renders rows and no detail area.

- [ ] **Step 3: Add provider families**

Create `lib/ui/github/github_providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gitopen/application/github/github_api.dart';
import 'package:gitopen/application/github/github_models.dart';
import 'package:gitopen/application/providers.dart';

typedef GitHubApiKey = ({RepoSlug slug, String token});
typedef GitHubPrKey = ({RepoSlug slug, String token, int number});

final githubPullRequestsProvider = FutureProvider.family
    .autoDispose<List<PullRequestInfo>, GitHubApiKey>(
      (ref, key) => ref
          .watch(gitHubApiProvider)
          .listPullRequests(key.slug, token: key.token),
    );

final githubPullRequestDetailProvider = FutureProvider.family
    .autoDispose<PullRequestDetail, GitHubPrKey>(
      (ref, key) => ref
          .watch(gitHubApiProvider)
          .getPullRequest(key.slug, key.number, token: key.token),
    );

final githubPullRequestFilesProvider = FutureProvider.family
    .autoDispose<List<PullRequestFile>, GitHubPrKey>(
      (ref, key) => ref
          .watch(gitHubApiProvider)
          .listPullRequestFiles(key.slug, key.number, token: key.token),
    );

final githubPullRequestReviewsProvider = FutureProvider.family
    .autoDispose<List<PullRequestReview>, GitHubPrKey>(
      (ref, key) => ref
          .watch(gitHubApiProvider)
          .listPullRequestReviews(key.slug, key.number, token: key.token),
    );

final githubPullRequestCommentsProvider = FutureProvider.family
    .autoDispose<List<PullRequestComment>, GitHubPrKey>(
      (ref, key) => ref
          .watch(gitHubApiProvider)
          .listPullRequestReviewComments(key.slug, key.number, token: key.token),
    );

final githubIssueCommentsProvider = FutureProvider.family
    .autoDispose<List<IssueCommentInfo>, GitHubPrKey>(
      (ref, key) => ref
          .watch(gitHubApiProvider)
          .listPullRequestIssueComments(key.slug, key.number, token: key.token),
    );

final githubWorkflowRunsProvider = FutureProvider.family.autoDispose<
    List<WorkflowRunInfo>,
    ({RepoSlug slug, String token, String? branch})>(
  (ref, key) => ref
      .watch(gitHubApiProvider)
      .listWorkflowRuns(key.slug, token: key.token, branch: key.branch),
);

final githubChecksProvider = FutureProvider.family
    .autoDispose<CheckSummary, ({RepoSlug slug, String token, String sha})>(
      (ref, key) => ref
          .watch(gitHubApiProvider)
          .prChecks(key.slug, key.sha, token: key.token),
    );
```

- [ ] **Step 4: Split reusable GitHub state widgets**

Move `_SignInCta` and `_ApiError` from `github_panel.dart` into `lib/ui/github/github_api_state.dart` with public names `GitHubSignInCta` and `GitHubApiErrorView`. Keep the exact copy of the sign-in behavior.

Create `lib/ui/github/github_tabs_bar.dart` with `GitHubTabsBar` and the existing segment button code. Public constructor:

```dart
class GitHubTabsBar extends StatelessWidget {
  const GitHubTabsBar({required this.active, required this.onSelect, super.key});
  final String active;
  final ValueChanged<String> onSelect;
}
```

- [ ] **Step 5: Move Actions tab unchanged**

Create `lib/ui/github/actions_tab.dart` with the existing `_ActionsTab` and `_RunRow`, renamed to public `GitHubActionsTab` and private `_RunRow`. It must use `githubWorkflowRunsProvider`.

- [ ] **Step 6: Implement PR list/detail split**

Create `lib/ui/github/pull_requests_tab.dart` with a stateful selected PR number:

```dart
class PullRequestsTab extends ConsumerStatefulWidget {
  const PullRequestsTab({
    required this.repo,
    required this.slug,
    required this.token,
    super.key,
  });

  final RepoLocation repo;
  final RepoSlug slug;
  final String token;

  @override
  ConsumerState<PullRequestsTab> createState() => _PullRequestsTabState();
}
```

Render a `Row` on wide layouts and a `Column` on narrow layouts using `LayoutBuilder`. The left side reads `githubPullRequestsProvider((slug: slug, token: token))`. Tapping a row sets `_selectedNumber`.

Create `lib/ui/github/pull_request_detail_view.dart`:

```dart
class PullRequestDetailView extends ConsumerWidget {
  const PullRequestDetailView({
    required this.repo,
    required this.slug,
    required this.token,
    required this.number,
    super.key,
  });

  final RepoLocation repo;
  final RepoSlug slug;
  final String token;
  final int number;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (slug: slug, token: token, number: number);
    final detailAsync = ref.watch(githubPullRequestDetailProvider(key));
    return detailAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => GitHubApiErrorView(
        error: e,
        onRetry: () => ref.invalidate(githubPullRequestDetailProvider(key)),
      ),
      data: (detail) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PullRequestHeader(detail: detail),
          Expanded(
            child: PullRequestFilesView(
              slug: slug,
              token: token,
              number: number,
            ),
          ),
        ],
      ),
    );
  }
}
```

Create `lib/ui/github/pull_request_files_view.dart` to render the first file by default. Use `parseGitHubPatch(file.patch)` and show raw line text in a monospace `SelectableText`.

- [ ] **Step 7: Keep GitHubPanel as composition only**

Reduce `lib/ui/github/github_panel.dart` to:

```dart
class GitHubPanel extends ConsumerStatefulWidget {
  const GitHubPanel({required this.repo, super.key});
  final RepoLocation repo;

  @override
  ConsumerState<GitHubPanel> createState() => _GitHubPanelState();
}

class _GitHubPanelState extends ConsumerState<GitHubPanel> {
  String _tab = 'prs';

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final slug = ref.watch(githubSlugProvider(widget.repo)).valueOrNull;
    if (slug == null) {
      return Center(
        child: Text(
          'Not a GitHub repository',
          style: TextStyle(
            color: palette.fg3,
            fontSize: 12.5,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }
    final profileAsync = ref.watch(repoActiveProfileProvider(widget.repo));
    if (profileAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final token = githubTokenOf(profileAsync.valueOrNull?.spec);
    if (token == null) return GitHubSignInCta(repo: widget.repo);
    return Column(
      children: [
        GitHubTabsBar(active: _tab, onSelect: (v) => setState(() => _tab = v)),
        Expanded(
          child: _tab == 'prs'
              ? PullRequestsTab(repo: widget.repo, slug: slug, token: token)
              : GitHubActionsTab(repo: widget.repo, slug: slug, token: token),
        ),
      ],
    );
  }
}
```

- [ ] **Step 8: Run and commit Task 3**

Run:

```powershell
flutter test test/ui/github/github_panel_test.dart test/application/github/github_pr_diff_test.dart -j 1
dart format lib/ui/github test/ui/github/github_panel_test.dart
flutter analyze
```

Expected: tests pass; analyze reports no new issues.

Commit:

```powershell
git add lib/ui/github test/ui/github/github_panel_test.dart
git commit -m "feat: add read-only GitHub PR workbench"
```

---

### Task 4: GitHub PR Create, Edit, Close/Reopen, Ready, and Merge

**Files:**
- Create: `lib/ui/github/pull_request_forms.dart`
- Modify: `lib/ui/github/pull_request_detail_view.dart`
- Modify: `lib/ui/github/pull_requests_tab.dart`
- Modify: `test/ui/github/github_panel_test.dart`

- [ ] **Step 1: Add fake mutation recording and failing widget tests**

In `_FakeApi`, add fields:

```dart
CreatePullRequestRequest? createdRequest;
UpdatePullRequestRequest? updatedRequest;
MergePullRequestRequest? mergedRequest;
bool markedReady = false;
```

Implement mutation methods by recording the request and returning deterministic detail. Add tests:

```dart
testWidgets('Create PR dialog calls createPullRequest', (tester) async {
  final api = _FakeApi();
  await _pump(tester, repo: repo, api: api, profile: profile);

  await tester.tap(find.text('Create PR'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('create-pr-title')), 'New PR');
  await tester.enterText(find.byKey(const Key('create-pr-body')), 'Body');
  await tester.enterText(find.byKey(const Key('create-pr-base')), 'main');
  await tester.enterText(find.byKey(const Key('create-pr-head')), 'feat/widget');
  await tester.tap(find.text('Create'));
  await tester.pumpAndSettle();

  expect(api.createdRequest?.title, 'New PR');
  expect(api.createdRequest?.base, 'main');
});

testWidgets('Merge PR dialog calls mergePullRequest', (tester) async {
  final api = _FakeApi();
  await _pump(tester, repo: repo, api: api, profile: profile);
  await tester.tap(find.text('Improve the widget'));
  await tester.pumpAndSettle();

  await tester.tap(find.text('Merge'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Squash'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Confirm merge'));
  await tester.pumpAndSettle();

  expect(api.mergedRequest?.method, PullRequestMergeMethod.squash);
});
```

- [ ] **Step 2: Run tests to verify failure**

Run: `flutter test test/ui/github/github_panel_test.dart -j 1`

Expected: FAIL because create and merge controls do not exist.

- [ ] **Step 3: Add PR forms**

Create `lib/ui/github/pull_request_forms.dart` with three dialogs:

```dart
final class PullRequestCreateFormResult {
  const PullRequestCreateFormResult(this.request);
  final CreatePullRequestRequest request;
}

final class PullRequestEditFormResult {
  const PullRequestEditFormResult(this.request);
  final UpdatePullRequestRequest request;
}

final class PullRequestMergeFormResult {
  const PullRequestMergeFormResult(this.request);
  final MergePullRequestRequest request;
}
```

Each dialog uses `showDialog<T>`, `TextEditingController`s, validates non-empty title/base/head for create, and returns the request. Add stable keys used by tests: `create-pr-title`, `create-pr-body`, `create-pr-base`, `create-pr-head`.

- [ ] **Step 4: Wire create PR**

In `PullRequestsTab`, add a top toolbar with `Create PR`. On click:

```dart
final result = await showCreatePullRequestDialog(context);
if (result == null || !context.mounted) return;
try {
  final created = await ref.read(gitHubApiProvider).createPullRequest(
    widget.slug,
    result.request,
    token: widget.token,
  );
  ref.invalidate(
    githubPullRequestsProvider((slug: widget.slug, token: widget.token)),
  );
  setState(() => _selectedNumber = created.number);
} on Object catch (e) {
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
  }
}
```

- [ ] **Step 5: Wire detail mutations**

In `PullRequestDetailView`, add action buttons:

- `Edit`: calls `updatePullRequest` with title/body/base.
- `Close`: calls `updatePullRequest(... state: 'closed')`.
- `Reopen`: visible when state is `closed`, calls `state: 'open'`.
- `Ready`: visible when `isDraft`, calls `markPullRequestReadyForReview`.
- `Merge`: calls `mergePullRequest` from dialog request.

After each success, invalidate:

```dart
ref
  ..invalidate(githubPullRequestDetailProvider(key))
  ..invalidate(githubPullRequestsProvider((slug: slug, token: token)));
```

For merge blocked errors, show the exception message inline below the action bar using state in the detail widget.

- [ ] **Step 6: Run and commit Task 4**

Run:

```powershell
flutter test test/ui/github/github_panel_test.dart test/infrastructure/github/github_rest_api_test.dart -j 1
dart format lib/ui/github test/ui/github/github_panel_test.dart
flutter analyze
```

Expected: tests pass; analyze reports no new issues.

Commit:

```powershell
git add lib/ui/github test/ui/github/github_panel_test.dart
git commit -m "feat: add GitHub PR mutations"
```

---

### Task 5: GitHub Review Drawer, Inline Comments, and Replies

**Files:**
- Modify: `lib/ui/github/pull_request_files_view.dart`
- Create: `lib/ui/github/pull_request_review_drawer.dart`
- Modify: `test/ui/github/github_panel_test.dart`

- [ ] **Step 1: Write failing review tests**

Extend `_FakeApi` with:

```dart
SubmitReviewRequest? submittedReview;
String? createdIssueComment;
String? replyBody;
```

Add tests:

```dart
testWidgets('queues a line comment and submits review', (tester) async {
  final api = _FakeApi();
  await _pump(tester, repo: repo, api: api, profile: profile);
  await tester.tap(find.text('Improve the widget'));
  await tester.pumpAndSettle();

  await tester.tap(find.byTooltip('Comment on line 2'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('review-line-comment-body')), 'Please adjust');
  await tester.tap(find.text('Queue comment'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('review-summary-body')), 'Looks close');
  await tester.tap(find.text('Comment'));
  await tester.pumpAndSettle();

  expect(api.submittedReview?.body, 'Looks close');
  expect(api.submittedReview?.comments.single.body, 'Please adjust');
  expect(api.submittedReview?.comments.single.path, 'lib/widget.dart');
});

testWidgets('adds a conversation comment', (tester) async {
  final api = _FakeApi();
  await _pump(tester, repo: repo, api: api, profile: profile);
  await tester.tap(find.text('Improve the widget'));
  await tester.pumpAndSettle();

  await tester.enterText(find.byKey(const Key('issue-comment-body')), 'Top level');
  await tester.tap(find.text('Add comment'));
  await tester.pumpAndSettle();

  expect(api.createdIssueComment, 'Top level');
});
```

- [ ] **Step 2: Run tests to verify failure**

Run: `flutter test test/ui/github/github_panel_test.dart -j 1`

Expected: FAIL because comment buttons and review drawer do not exist.

- [ ] **Step 3: Create review drawer state**

Create `lib/ui/github/pull_request_review_drawer.dart`:

```dart
final class QueuedReviewComment {
  const QueuedReviewComment({
    required this.path,
    required this.body,
    required this.line,
    required this.side,
  });

  final String path;
  final String body;
  final int line;
  final String side;

  DraftReviewComment toRequest() => DraftReviewComment(
    path: path,
    body: body,
    line: line,
    side: side,
  );
}
```

Add `PullRequestReviewDrawer` as a `ConsumerStatefulWidget` with:

- `List<QueuedReviewComment> queuedComments`
- summary body controller with key `review-summary-body`
- event buttons `Comment`, `Approve`, `Request changes`
- issue comment controller with key `issue-comment-body`
- `onSubmitted` invalidates review/comment providers

- [ ] **Step 4: Wire line comment affordance**

In `PullRequestFilesView`, for each commentable `GitHubPatchLine`, render an icon button:

```dart
IconButton(
  tooltip: 'Comment on line ${line.commentLine}',
  icon: const Icon(Icons.add_comment_outlined, size: 14),
  onPressed: () => widget.onLineCommentRequested(
    file.filename,
    line.commentLine!,
    line.side,
  ),
)
```

The drawer opens a small dialog with key `review-line-comment-body`, then stores the queued comment.

- [ ] **Step 5: Submit review and comments**

`PullRequestReviewDrawer` calls:

```dart
await ref.read(gitHubApiProvider).createReview(
  slug,
  number,
  SubmitReviewRequest(
    event: event,
    body: summaryController.text,
    comments: [for (final c in queuedComments) c.toRequest()],
  ),
  token: token,
);
```

For top-level conversation comments:

```dart
await ref.read(gitHubApiProvider).createIssueComment(
  slug,
  number,
  issueCommentController.text,
  token: token,
);
```

After success, clear controllers, clear queued comments, and invalidate `githubPullRequestReviewsProvider`, `githubPullRequestCommentsProvider`, and `githubIssueCommentsProvider`.

- [ ] **Step 6: Run and commit Task 5**

Run:

```powershell
flutter test test/ui/github/github_panel_test.dart test/application/github/github_pr_diff_test.dart -j 1
dart format lib/ui/github test/ui/github/github_panel_test.dart
flutter analyze
```

Expected: tests pass; analyze reports no new issues.

Commit:

```powershell
git add lib/ui/github test/ui/github/github_panel_test.dart
git commit -m "feat: add GitHub PR review comments"
```

---

### Task 6: Git LFS Models, Parsers, CLI Adapter, and Providers

**Files:**
- Create: `lib/application/git_lfs/git_lfs_models.dart`
- Create: `lib/application/git_lfs/git_lfs_operations.dart`
- Create: `lib/infrastructure/git_lfs/git_lfs_parsers.dart`
- Create: `lib/infrastructure/git_lfs/git_cli_lfs_operations.dart`
- Modify: `lib/application/providers.dart`
- Create: `test/infrastructure/git_lfs/git_lfs_parsers_test.dart`
- Create: `test/infrastructure/git_lfs/git_cli_lfs_operations_test.dart`
- Modify: `test/application/providers_test.dart`

- [ ] **Step 1: Write parser tests**

Create `test/infrastructure/git_lfs/git_lfs_parsers_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:gitopen/infrastructure/git_lfs/git_lfs_parsers.dart';

void main() {
  test('parseGitLfsVersion extracts version', () {
    expect(parseGitLfsVersion('git-lfs/3.6.1 (GitHub; windows amd64; go 1.23.0)'), '3.6.1');
  });

  test('parseGitLfsTrackList parses patterns', () {
    final patterns = parseGitLfsTrackList('*.psd filter=lfs diff=lfs merge=lfs -text\nassets/** filter=lfs diff=lfs merge=lfs -text\n');

    expect(patterns, hasLength(2));
    expect(patterns.first.pattern, '*.psd');
    expect(patterns.first.attributes, 'filter=lfs diff=lfs merge=lfs -text');
  });

  test('parseGitLfsLsFiles parses oid, size, and path', () {
    final files = parseGitLfsLsFiles('a123456789abcdef * big/file.bin (12 MB)\n');

    expect(files.single.oid, 'a123456789abcdef');
    expect(files.single.path, 'big/file.bin');
    expect(files.single.sizeLabel, '12 MB');
  });
}
```

- [ ] **Step 2: Run parser tests to verify failure**

Run: `flutter test test/infrastructure/git_lfs/git_lfs_parsers_test.dart -j 1`

Expected: FAIL because LFS parser files do not exist.

- [ ] **Step 3: Add LFS models and port**

Create `lib/application/git_lfs/git_lfs_models.dart`:

```dart
import 'package:equatable/equatable.dart';

final class GitLfsStatus extends Equatable {
  const GitLfsStatus({
    required this.isInstalled,
    required this.version,
    required this.isRepoConfigured,
    required this.hasAttributes,
  });

  final bool isInstalled;
  final String? version;
  final bool isRepoConfigured;
  final bool hasAttributes;

  @override
  List<Object?> get props => [
    isInstalled,
    version,
    isRepoConfigured,
    hasAttributes,
  ];
}

final class GitLfsTrackedPattern extends Equatable {
  const GitLfsTrackedPattern({
    required this.pattern,
    required this.attributes,
    required this.source,
  });

  final String pattern;
  final String attributes;
  final String source;

  @override
  List<Object?> get props => [pattern, attributes, source];
}

final class GitLfsFile extends Equatable {
  const GitLfsFile({
    required this.oid,
    required this.path,
    required this.sizeLabel,
  });

  final String oid;
  final String path;
  final String sizeLabel;

  @override
  List<Object?> get props => [oid, path, sizeLabel];
}
```

Create `lib/application/git_lfs/git_lfs_operations.dart`:

```dart
import 'package:gitopen/application/auth/auth_spec.dart';
import 'package:gitopen/application/git/git_progress.dart';
import 'package:gitopen/application/git/git_result.dart';
import 'package:gitopen/application/git_lfs/git_lfs_models.dart';
import 'package:gitopen/domain/repositories/repo_location.dart';

abstract interface class GitLfsOperations {
  Future<GitLfsStatus> status(RepoLocation repo);
  Future<List<GitLfsTrackedPattern>> trackedPatterns(RepoLocation repo);
  Future<List<GitLfsFile>> files(RepoLocation repo);
  Future<GitResult<void>> installLocal(RepoLocation repo);
  Future<GitResult<void>> track(RepoLocation repo, String pattern);
  Future<GitResult<void>> untrack(RepoLocation repo, String pattern);
  Stream<GitProgress> fetch(RepoLocation repo, {AuthSpec? auth});
  Stream<GitProgress> pull(RepoLocation repo, {AuthSpec? auth});
  Stream<GitProgress> push(RepoLocation repo, {AuthSpec? auth});
}
```

- [ ] **Step 4: Implement parser helpers**

Create `lib/infrastructure/git_lfs/git_lfs_parsers.dart`:

```dart
import 'package:gitopen/application/git_lfs/git_lfs_models.dart';

String? parseGitLfsVersion(String raw) {
  final match = RegExp(r'git-lfs/([^\s]+)').firstMatch(raw.trim());
  return match?.group(1);
}

List<GitLfsTrackedPattern> parseGitLfsTrackList(String raw) {
  return raw
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .map((line) {
        final parts = line.split(RegExp(r'\s+'));
        return GitLfsTrackedPattern(
          pattern: parts.first,
          attributes: parts.skip(1).join(' '),
          source: '.gitattributes',
        );
      })
      .toList(growable: false);
}

List<GitLfsFile> parseGitLfsLsFiles(String raw) {
  final re = RegExp(r'^([0-9a-fA-F]+)\s+[-*]\s+(.+?)\s+\(([^)]+)\)$');
  return raw
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .map((line) {
        final match = re.firstMatch(line);
        if (match == null) {
          return GitLfsFile(oid: '', path: line, sizeLabel: '');
        }
        return GitLfsFile(
          oid: match.group(1)!,
          path: match.group(2)!,
          sizeLabel: match.group(3)!,
        );
      })
      .toList(growable: false);
}
```

- [ ] **Step 5: Implement CLI adapter**

Create `lib/infrastructure/git_lfs/git_cli_lfs_operations.dart`. Use `GitResultRunner` for simple commands and `CredentialHelper` for sync commands. Status must:

- run `git lfs version`
- return `GitLfsStatus(isInstalled: false, version: null, isRepoConfigured: false, hasAttributes: false)` when stderr contains `git: 'lfs' is not a git command` or `not a git command`
- run `git config --local --get filter.lfs.clean` to detect repo-local setup
- check `File(p.join(repo.path, '.gitattributes')).existsSync()` for attributes

Core snippets:

```dart
@override
Future<GitLfsStatus> status(RepoLocation repo) async {
  try {
    final versionRaw = await _runner.run(repo.path, ['lfs', 'version']);
    final version = parseGitLfsVersion(versionRaw);
    var configured = false;
    try {
      final clean = await _runner.run(repo.path, [
        'config',
        '--local',
        '--get',
        'filter.lfs.clean',
      ]);
      configured = clean.contains('git-lfs');
    } on GitProcessException {
      configured = false;
    }
    return GitLfsStatus(
      isInstalled: true,
      version: version,
      isRepoConfigured: configured,
      hasAttributes: File(p.join(repo.path, '.gitattributes')).existsSync(),
    );
  } on GitProcessException catch (e) {
    if (e.stderr.contains('not a git command')) {
      return const GitLfsStatus(
        isInstalled: false,
        version: null,
        isRepoConfigured: false,
        hasAttributes: false,
      );
    }
    rethrow;
  }
}
```

Simple commands:

```dart
@override
Future<List<GitLfsTrackedPattern>> trackedPatterns(RepoLocation repo) async =>
    parseGitLfsTrackList(await _runner.run(repo.path, ['lfs', 'track', '--list']));

@override
Future<List<GitLfsFile>> files(RepoLocation repo) async =>
    parseGitLfsLsFiles(await _runner.run(repo.path, ['lfs', 'ls-files', '--long', '--size']));

@override
Future<GitResult<void>> installLocal(RepoLocation repo) =>
    _git.runVoid(repo, ['lfs', 'install', '--local']);

@override
Future<GitResult<void>> track(RepoLocation repo, String pattern) =>
    _git.runVoid(repo, ['lfs', 'track', pattern]);

@override
Future<GitResult<void>> untrack(RepoLocation repo, String pattern) =>
    _git.runVoid(repo, ['lfs', 'untrack', pattern]);
```

Sync commands must stream progress and use repository-scoped LFS commands:

```dart
@override
Stream<GitProgress> fetch(RepoLocation repo, {AuthSpec? auth}) =>
    _runLfsProgress(repo, ['lfs', 'fetch'], auth: auth);

@override
Stream<GitProgress> pull(RepoLocation repo, {AuthSpec? auth}) =>
    _runLfsProgress(repo, ['lfs', 'pull'], auth: auth);

@override
Stream<GitProgress> push(RepoLocation repo, {AuthSpec? auth}) =>
    _runLfsProgress(repo, ['lfs', 'push', 'origin'], auth: auth);
```

`_runLfsProgress` uses `CredentialHelper.setup(auth)`, prepends `helper.extraArgs` before `lfs`, starts `Process.start(_runner.executable, effectiveArgs, workingDirectory: repo.path, environment: buildGitEnvironment(helper.env))`, yields `GitProgress(phase: line, rawLine: line)` for every stdout/stderr line, and throws `GitProcessException(effectiveArgs, exit, stderrTail)` on non-zero exit. Do not call `git lfs install` without `--local`.

- [ ] **Step 6: Add providers**

Modify `lib/application/providers.dart` imports:

```dart
import 'package:gitopen/application/git_lfs/git_lfs_models.dart';
import 'package:gitopen/application/git_lfs/git_lfs_operations.dart';
import 'package:gitopen/infrastructure/git_lfs/git_cli_lfs_operations.dart';
```

Add providers near git write providers:

```dart
final gitLfsOperationsProvider = Provider<GitLfsOperations>((ref) {
  return GitCliLfsOperations(runner: ref.watch(gitProcessRunnerProvider));
});

final gitLfsStatusProvider =
    FutureProvider.family<GitLfsStatus, RepoLocation>((ref, repo) {
      return ref.watch(gitLfsOperationsProvider).status(repo);
    });

final gitLfsTrackedPatternsProvider =
    FutureProvider.family<List<GitLfsTrackedPattern>, RepoLocation>((ref, repo) {
      return ref.watch(gitLfsOperationsProvider).trackedPatterns(repo);
    });

final gitLfsFilesProvider =
    FutureProvider.family<List<GitLfsFile>, RepoLocation>((ref, repo) {
      return ref.watch(gitLfsOperationsProvider).files(repo);
    });
```

- [ ] **Step 7: Add real-git CLI test with skip**

Create `test/infrastructure/git_lfs/git_cli_lfs_operations_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gitopen/domain/repositories/repo_id.dart';
import 'package:gitopen/domain/repositories/repo_location.dart';
import 'package:gitopen/infrastructure/git_lfs/git_cli_lfs_operations.dart';

import '../../_helpers/repo_fixture.dart';

void main() {
  test('track and untrack pattern when git lfs is available', () async {
    final version = await Process.run('git', ['lfs', 'version']);
    if (version.exitCode != 0) {
      markTestSkipped('git lfs is not installed');
      return;
    }

    final fixture = await RepoFixture.empty();
    addTearDown(fixture.dispose);
    final repo = RepoLocation(RepoId.newId(), fixture.path, 'repo');
    final sut = GitCliLfsOperations();

    await sut.installLocal(repo);
    await sut.track(repo, '*.bin');
    expect((await sut.trackedPatterns(repo)).single.pattern, '*.bin');
    await sut.untrack(repo, '*.bin');
    expect(await sut.trackedPatterns(repo), isEmpty);
  });
}
```

- [ ] **Step 8: Run and commit Task 6**

Run:

```powershell
flutter test test/infrastructure/git_lfs/git_lfs_parsers_test.dart test/infrastructure/git_lfs/git_cli_lfs_operations_test.dart test/application/providers_test.dart -j 1
dart format lib/application/git_lfs lib/infrastructure/git_lfs test/infrastructure/git_lfs lib/application/providers.dart test/application/providers_test.dart
flutter analyze
```

Expected: parser tests pass; CLI test passes or is explicitly skipped when Git LFS is unavailable; provider test passes.

Commit:

```powershell
git add lib/application/git_lfs lib/infrastructure/git_lfs lib/application/providers.dart test/infrastructure/git_lfs test/application/providers_test.dart
git commit -m "feat: add Git LFS operations"
```

---

### Task 7: LFS Service, Shared Action Bridges, and Controller

**Files:**
- Create: `lib/application/git_lfs/git_lfs_service.dart`
- Modify: `lib/application/providers.dart`
- Create: `lib/ui/git/git_action_bridges.dart`
- Modify: `lib/ui/git/git_actions_controller.dart`
- Create: `lib/ui/lfs/lfs_actions_controller.dart`
- Create: `test/application/git_lfs/git_lfs_service_test.dart`

- [ ] **Step 1: Write service tests**

Create `test/application/git_lfs/git_lfs_service_test.dart` with fake LFS operations:

```dart
test('track returns success and invalidates reads', () async {
  final lfs = _FakeLfsOperations();
  final sut = GitLfsService(
    lfs: lfs,
    resolveProfile: (_) async => null,
    errorText: (e) => e.toString(),
  );

  final result = await sut.track(_repo, '*.bin');

  expect(result.outcome, ActionOutcome.success);
  expect(result.invalidate, contains(RepoDataScope.reads));
  expect(lfs.trackedPattern, '*.bin');
});

test('fetch drives progress sink', () async {
  final progress = _FakeProgressSink();
  final sut = GitLfsService(
    lfs: _FakeLfsOperations()
      ..progress = const GitProgress(phase: 'Downloading', rawLine: 'Downloading'),
    resolveProfile: (_) async => null,
    errorText: (e) => e.toString(),
  );

  final result = await sut.fetch(
    _repo,
    prompt: _NoopAuthPrompt(),
    progress: progress,
  );

  expect(result.outcome, ActionOutcome.success);
  expect(progress.phases, contains('Downloading'));
});
```

Add the supporting fakes in the same test file:

```dart
final _repo = RepoLocation(RepoId.newId(), 'unused', 'repo');

final class _FakeLfsOperations implements GitLfsOperations {
  String? trackedPattern;
  GitProgress? progress;

  @override
  Future<GitLfsStatus> status(RepoLocation repo) async => const GitLfsStatus(
    isInstalled: true,
    version: '3.6.1',
    isRepoConfigured: true,
    hasAttributes: true,
  );

  @override
  Future<List<GitLfsTrackedPattern>> trackedPatterns(RepoLocation repo) async =>
      const [];

  @override
  Future<List<GitLfsFile>> files(RepoLocation repo) async => const [];

  @override
  Future<GitResult<void>> installLocal(RepoLocation repo) async =>
      const GitSuccess(null);

  @override
  Future<GitResult<void>> track(RepoLocation repo, String pattern) async {
    trackedPattern = pattern;
    return const GitSuccess(null);
  }

  @override
  Future<GitResult<void>> untrack(RepoLocation repo, String pattern) async =>
      const GitSuccess(null);

  @override
  Stream<GitProgress> fetch(RepoLocation repo, {AuthSpec? auth}) async* {
    final event = progress;
    if (event != null) yield event;
  }

  @override
  Stream<GitProgress> pull(RepoLocation repo, {AuthSpec? auth}) => fetch(repo);

  @override
  Stream<GitProgress> push(RepoLocation repo, {AuthSpec? auth}) => fetch(repo);
}

final class _FakeProgressSink implements ProgressSink {
  final phases = <String>[];

  @override
  String start(OpKind kind, String label, {RepoLocation? repo}) => 'op';

  @override
  void progress(String id, double? fraction, String phase) {
    phases.add(phase);
  }

  @override
  void success(String id) {}

  @override
  void failure(String id, String message) {}
}

final class _NoopAuthPrompt implements AuthPrompt {
  @override
  Future<AuthProfile?> forAccount(
    RepoLocation repo,
    AuthFailureReason reason,
  ) async =>
      null;
}
```

- [ ] **Step 2: Run tests to verify failure**

Run: `flutter test test/application/git_lfs/git_lfs_service_test.dart -j 1`

Expected: FAIL because `GitLfsService` does not exist.

- [ ] **Step 3: Implement LFS service**

Create `lib/application/git_lfs/git_lfs_service.dart` using `ActionResult`, `ActionOutcome`, `RepoDataScope`, `ProgressSink`, and `AuthPrompt` from `git_actions_service.dart`/`git_action_ports.dart`:

```dart
final class GitLfsService {
  GitLfsService({
    required GitLfsOperations lfs,
    required Future<AuthProfile?> Function(RepoLocation repo) resolveProfile,
    required String Function(Object error) errorText,
    AuthFailureClassifier classifier = const AuthFailureClassifier(),
  }) : _lfs = lfs,
       _resolveProfile = resolveProfile,
       _errorText = errorText,
       _classifier = classifier;

  final GitLfsOperations _lfs;
  final Future<AuthProfile?> Function(RepoLocation repo) _resolveProfile;
  final String Function(Object error) _errorText;
  final AuthFailureClassifier _classifier;

  Future<ActionResult> installLocal(RepoLocation repo) =>
      _simple('Git LFS install', _lfs.installLocal(repo));

  Future<ActionResult> track(RepoLocation repo, String pattern) =>
      _simple('Git LFS track', _lfs.track(repo, pattern));

  Future<ActionResult> untrack(RepoLocation repo, String pattern) =>
      _simple('Git LFS untrack', _lfs.untrack(repo, pattern));

  Future<ActionResult> fetch(
    RepoLocation repo, {
    required AuthPrompt prompt,
    required ProgressSink progress,
  }) =>
      _runStream(
        OpKind.fetch,
        'Git LFS fetch',
        repo,
        (auth) => _lfs.fetch(repo, auth: auth),
        prompt: prompt,
        progress: progress,
      );
}
```

Implement `pull`, `push`, `_simple`, and `_runStream` with the same auth retry shape as `GitActionsService._runStream`. `_simple` returns `ActionResult(ActionOutcome.success, invalidate: {RepoDataScope.reads})` on `GitSuccess` and an error message on `GitFailure`.

- [ ] **Step 4: Wire the service provider**

Modify `lib/application/providers.dart` imports:

```dart
import 'package:gitopen/application/git_lfs/git_lfs_service.dart';
```

Add the service provider after `gitLfsOperationsProvider`:

```dart
final gitLfsServiceProvider = Provider<GitLfsService>((ref) {
  return GitLfsService(
    lfs: ref.watch(gitLfsOperationsProvider),
    resolveProfile: (repo) =>
        ref.read(authResolverProvider).resolveForRepo(repo),
    errorText: ref.watch(gitErrorTextProvider),
  );
});
```

- [ ] **Step 5: Extract shared UI bridges**

Create `lib/ui/git/git_action_bridges.dart` with public `DialogAuthPrompt` and `OperationsProgressSink`. Move the current private `_DialogAuthPrompt` and `_OperationsProgressSink` implementations from `git_actions_controller.dart` without behavior changes.

Modify `git_actions_controller.dart`:

- import `package:gitopen/ui/git/git_action_bridges.dart`
- replace `_DialogAuthPrompt(context, _ref)` with `DialogAuthPrompt(context, _ref)`
- replace `_OperationsProgressSink(_ref)` with `OperationsProgressSink(_ref)`
- remove the old private class definitions

- [ ] **Step 6: Add LFS actions controller**

Create `lib/ui/lfs/lfs_actions_controller.dart`:

```dart
final lfsActionsControllerProvider = Provider<LfsActionsController>(
  LfsActionsController.new,
);

class LfsActionsController {
  LfsActionsController(this._ref);
  final Ref _ref;

  Future<ActionResult> installLocal(BuildContext context, RepoLocation repo) =>
      _runLocal(context, repo, () => _ref.read(gitLfsServiceProvider).installLocal(repo));

  Future<ActionResult> track(
    BuildContext context,
    RepoLocation repo,
    String pattern,
  ) =>
      _runLocal(context, repo, () => _ref.read(gitLfsServiceProvider).track(repo, pattern));

  Future<ActionResult> fetch(BuildContext context, RepoLocation repo) => _run(
    context,
    repo,
    (prompt, progress) => _ref
        .read(gitLfsServiceProvider)
        .fetch(repo, prompt: prompt, progress: progress),
  );

  void _invalidate(RepoLocation repo) {
    _ref
      ..invalidate(gitLfsStatusProvider(repo))
      ..invalidate(gitLfsTrackedPatternsProvider(repo))
      ..invalidate(gitLfsFilesProvider(repo))
      ..invalidate(repoStatusProvider(repo));
  }
}
```

Complete `untrack`, `pull`, `push`, `_run`, `_runLocal`, and snack display by mirroring `GitActionsController`.

- [ ] **Step 7: Run and commit Task 7**

Run:

```powershell
flutter test test/application/git_lfs/git_lfs_service_test.dart test/ui/git/git_actions_controller_test.dart -j 1
dart format lib/application/git_lfs lib/application/providers.dart lib/ui/git lib/ui/lfs test/application/git_lfs
flutter analyze
```

Expected: tests pass; analyze reports no new issues.

Commit:

```powershell
git add lib/application/git_lfs lib/application/providers.dart lib/ui/git lib/ui/lfs test/application/git_lfs
git commit -m "feat: orchestrate Git LFS actions"
```

---

### Task 8: LFS View and Main Navigation

**Files:**
- Create: `lib/ui/lfs/lfs_panel.dart`
- Modify: `lib/application/main_view_provider.dart`
- Modify: `lib/ui/shell/view_selector.dart`
- Modify: `lib/main.dart`
- Create: `test/ui/lfs/lfs_panel_test.dart`

- [ ] **Step 1: Write LFS widget tests**

Create `test/ui/lfs/lfs_panel_test.dart` with provider overrides:

```dart
testWidgets('shows not-installed state', (tester) async {
  await _pumpLfs(
    tester,
    status: const GitLfsStatus(
      isInstalled: false,
      version: null,
      isRepoConfigured: false,
      hasAttributes: false,
    ),
  );

  expect(find.text('Git LFS is not installed'), findsOneWidget);
});

testWidgets('shows repo setup action when LFS is installed but not configured', (tester) async {
  await _pumpLfs(
    tester,
    status: const GitLfsStatus(
      isInstalled: true,
      version: '3.6.1',
      isRepoConfigured: false,
      hasAttributes: false,
    ),
  );

  expect(find.text('Install in repo'), findsOneWidget);
});

testWidgets('shows tracked patterns and files when ready', (tester) async {
  await _pumpLfs(
    tester,
    status: const GitLfsStatus(
      isInstalled: true,
      version: '3.6.1',
      isRepoConfigured: true,
      hasAttributes: true,
    ),
    patterns: const [
      GitLfsTrackedPattern(
        pattern: '*.bin',
        attributes: 'filter=lfs diff=lfs merge=lfs -text',
        source: '.gitattributes',
      ),
    ],
    files: const [
      GitLfsFile(oid: 'abcdef123456', path: 'assets/big.bin', sizeLabel: '12 MB'),
    ],
  );

  expect(find.text('*.bin'), findsOneWidget);
  expect(find.text('assets/big.bin'), findsOneWidget);
  expect(find.text('12 MB'), findsOneWidget);
});
```

Add `_pumpLfs` in the same file:

```dart
Future<void> _pumpLfs(
  WidgetTester tester, {
  required GitLfsStatus status,
  List<GitLfsTrackedPattern> patterns = const [],
  List<GitLfsFile> files = const [],
}) async {
  final repo = RepoLocation(RepoId.newId(), 'unused', 'repo');
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        gitLfsStatusProvider.overrideWith((ref, repo) async => status),
        gitLfsTrackedPatternsProvider.overrideWith(
          (ref, repo) async => patterns,
        ),
        gitLfsFilesProvider.overrideWith((ref, repo) async => files),
      ],
      child: MaterialApp(
        theme: ThemeData(extensions: [AppPalette.dark()]),
        home: Scaffold(body: SizedBox(width: 800, height: 500, child: LfsPanel(repo: repo))),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
```

- [ ] **Step 2: Run tests to verify failure**

Run: `flutter test test/ui/lfs/lfs_panel_test.dart -j 1`

Expected: FAIL because LFS panel does not exist.

- [ ] **Step 3: Implement LFS panel**

Create `lib/ui/lfs/lfs_panel.dart`:

```dart
class LfsPanel extends ConsumerWidget {
  const LfsPanel({required this.repo, super.key});

  final RepoLocation repo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(gitLfsStatusProvider(repo));
    return statusAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _LfsError(message: '$e'),
      data: (status) {
        if (!status.isInstalled) {
          return const _LfsNotInstalled();
        }
        if (!status.isRepoConfigured) {
          return _LfsSetup(repo: repo, status: status);
        }
        return _LfsReady(repo: repo, status: status);
      },
    );
  }
}
```

`_LfsReady` renders:

- status row with version
- tracked patterns from `gitLfsTrackedPatternsProvider(repo)`
- files from `gitLfsFilesProvider(repo)`
- buttons `Fetch`, `Pull`, `Push`
- button `Add pattern`

Use `LfsActionsController` for actions. Add pattern dialog uses a `TextField` with key `lfs-pattern-input`. Remove pattern action calls `untrack`.

- [ ] **Step 4: Add LFS main view**

Update `lib/application/main_view_provider.dart`:

```dart
enum MainView { graph, changes, github, lfs }
```

Update `lib/ui/shell/view_selector.dart` to always render:

```dart
_SegmentButton(
  label: 'LFS',
  icon: Icons.storage_outlined,
  selected: current == MainView.lfs,
  onTap: () => ref.read(mainViewProvider.notifier).state = MainView.lfs,
),
```

Update `lib/main.dart` main view switch:

```dart
: view == MainView.github
? GitHubPanel(repo: repo)
: view == MainView.lfs
? LfsPanel(repo: repo)
: VerticalSplitter(...)
```

Import `package:gitopen/ui/lfs/lfs_panel.dart`.

- [ ] **Step 5: Run and commit Task 8**

Run:

```powershell
flutter test test/ui/lfs/lfs_panel_test.dart test/ui/github/github_panel_test.dart -j 1
dart format lib/ui/lfs lib/application/main_view_provider.dart lib/ui/shell/view_selector.dart lib/main.dart test/ui/lfs
flutter analyze
```

Expected: tests pass; analyze reports no new issues.

Commit:

```powershell
git add lib/ui/lfs lib/application/main_view_provider.dart lib/ui/shell/view_selector.dart lib/main.dart test/ui/lfs
git commit -m "feat: add Git LFS view"
```

---

### Task 9: Full Verification and Final Polish

**Files:**
- Modify only files touched by previous tasks if verification exposes a concrete issue.

- [ ] **Step 1: Run targeted suites**

Run:

```powershell
flutter test test/infrastructure/github/github_rest_api_test.dart test/application/github/github_pr_diff_test.dart test/ui/github/github_panel_test.dart test/infrastructure/git_lfs/git_lfs_parsers_test.dart test/infrastructure/git_lfs/git_cli_lfs_operations_test.dart test/application/git_lfs/git_lfs_service_test.dart test/ui/lfs/lfs_panel_test.dart -j 1
```

Expected: all pass, except `git_cli_lfs_operations_test.dart` may report an explicit skip when `git lfs` is unavailable.

- [ ] **Step 2: Run full tests**

Run:

```powershell
flutter test -j 2
```

Expected: all tests pass.

- [ ] **Step 3: Run analysis and whitespace checks**

Run:

```powershell
flutter analyze
git diff --check
```

Expected: no analyzer issues and no whitespace errors.

- [ ] **Step 4: Inspect changed files**

Run:

```powershell
git status --short
git diff --stat origin/main...HEAD
```

Expected: only GitHub PR workbench, Git LFS, tests, and docs are changed.

- [ ] **Step 5: Final commit if verification required fixes**

If Step 1-3 required changes, commit them:

```powershell
git add lib test
git commit -m "fix: polish GitHub PR and LFS integration"
```

Expected: branch contains small commits for each tranche and working tree is clean.
