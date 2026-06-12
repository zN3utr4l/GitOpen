import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gitopen/application/github/github_models.dart';
import 'package:gitopen/application/providers.dart';

typedef GitHubApiKey = ({RepoSlug slug, String token});
typedef GitHubPrKey = ({RepoSlug slug, String token, int number});

final AutoDisposeFutureProviderFamily<List<PullRequestInfo>, GitHubApiKey>
githubPullRequestsProvider = FutureProvider.family
    .autoDispose<List<PullRequestInfo>, GitHubApiKey>(
      (ref, key) => ref
          .watch(gitHubApiProvider)
          .listPullRequests(key.slug, token: key.token),
    );

final AutoDisposeFutureProviderFamily<PullRequestDetail, GitHubPrKey>
githubPullRequestDetailProvider = FutureProvider.family
    .autoDispose<PullRequestDetail, GitHubPrKey>(
      (ref, key) => ref
          .watch(gitHubApiProvider)
          .getPullRequest(key.slug, key.number, token: key.token),
    );

final AutoDisposeFutureProviderFamily<List<PullRequestFile>, GitHubPrKey>
githubPullRequestFilesProvider = FutureProvider.family
    .autoDispose<List<PullRequestFile>, GitHubPrKey>(
      (ref, key) => ref
          .watch(gitHubApiProvider)
          .listPullRequestFiles(key.slug, key.number, token: key.token),
    );

final AutoDisposeFutureProviderFamily<List<PullRequestReview>, GitHubPrKey>
githubPullRequestReviewsProvider = FutureProvider.family
    .autoDispose<List<PullRequestReview>, GitHubPrKey>(
      (ref, key) => ref
          .watch(gitHubApiProvider)
          .listPullRequestReviews(key.slug, key.number, token: key.token),
    );

final AutoDisposeFutureProviderFamily<List<PullRequestComment>, GitHubPrKey>
githubPullRequestCommentsProvider = FutureProvider.family
    .autoDispose<List<PullRequestComment>, GitHubPrKey>(
      (ref, key) => ref
          .watch(gitHubApiProvider)
          .listPullRequestReviewComments(
            key.slug,
            key.number,
            token: key.token,
          ),
    );

final AutoDisposeFutureProviderFamily<List<IssueCommentInfo>, GitHubPrKey>
githubIssueCommentsProvider = FutureProvider.family
    .autoDispose<List<IssueCommentInfo>, GitHubPrKey>(
      (ref, key) => ref
          .watch(gitHubApiProvider)
          .listPullRequestIssueComments(key.slug, key.number, token: key.token),
    );

final AutoDisposeFutureProviderFamily<
  List<WorkflowRunInfo>,
  ({RepoSlug slug, String token, String? branch})
>
githubWorkflowRunsProvider = FutureProvider.family
    .autoDispose<
      List<WorkflowRunInfo>,
      ({RepoSlug slug, String token, String? branch})
    >(
      (ref, key) => ref
          .watch(gitHubApiProvider)
          .listWorkflowRuns(key.slug, token: key.token, branch: key.branch),
    );

final AutoDisposeFutureProviderFamily<
  CheckSummary,
  ({RepoSlug slug, String token, String sha})
>
githubChecksProvider = FutureProvider.family
    .autoDispose<CheckSummary, ({RepoSlug slug, String token, String sha})>(
      (ref, key) => ref
          .watch(gitHubApiProvider)
          .prChecks(key.slug, key.sha, token: key.token),
    );
