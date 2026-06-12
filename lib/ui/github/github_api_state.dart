import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gitopen/application/github/github_api.dart';
import 'package:gitopen/application/providers.dart';
import 'package:gitopen/domain/repositories/repo_location.dart';
import 'package:gitopen/ui/dialogs/auth_dialog.dart';
import 'package:gitopen/ui/theme/app_palette.dart';

class GitHubSignInCta extends ConsumerWidget {
  const GitHubSignInCta({required this.repo, super.key});

  final RepoLocation repo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_outlined, size: 32, color: palette.fg3),
          const SizedBox(height: 10),
          Text(
            'Sign in to see pull requests and workflow runs.',
            style: TextStyle(color: palette.fg2, fontSize: 12.5),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            icon: const Icon(Icons.login, size: 14),
            label: const Text('Sign in with GitHub'),
            onPressed: () async {
              final profile = await AuthDialog.show(context, 'github.com');
              if (profile == null) return;
              await ref
                  .read(appSettingsProvider.notifier)
                  .setAuthBinding(repo.id.value, profile.id);
              ref.invalidate(repoActiveProfileProvider(repo));
            },
          ),
        ],
      ),
    );
  }
}

class GitHubApiErrorView extends StatelessWidget {
  const GitHubApiErrorView({
    required this.error,
    required this.onRetry,
    super.key,
  });

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final message = error is GitHubApiException
        ? error.toString()
        : 'GitHub request failed: $error';
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: palette.fg2, fontSize: 12.5),
          ),
          const SizedBox(height: 10),
          OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
