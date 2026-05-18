import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../application/auth/auth_profile.dart';
import '../../../application/git/auth_spec.dart';
import '../../../application/providers.dart';
import '../../dialogs/auth_dialog.dart';
import '../../dialogs/confirm_dialog.dart';
import '../../theme/app_palette.dart';

final _profilesProvider =
    FutureProvider.autoDispose<List<AuthProfile>>((ref) async {
  // Watching the binding map ensures the list refreshes when a binding
  // change indirectly mutates settings; the store itself is the source
  // of truth for the profile list.
  ref.watch(appSettingsProvider.select((s) => s.authRepoBindings));
  return ref.read(authProfileStoreProvider).list();
});

class AuthenticationSection extends ConsumerWidget {
  const AuthenticationSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = AppPalette.of(context);
    final profiles = ref.watch(_profilesProvider);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('Saved accounts',
              style: TextStyle(
                  color: p.fg0, fontSize: 14, fontWeight: FontWeight.w600)),
          const Spacer(),
          ElevatedButton.icon(
            icon: const Icon(Icons.add, size: 14),
            label: const Text('Add account'),
            onPressed: () async {
              final host = await _promptHost(context);
              if (host == null || host.isEmpty) return;
              if (context.mounted) await AuthDialog.show(context, host);
              ref.invalidate(_profilesProvider);
            },
          ),
        ]),
        const SizedBox(height: 16),
        profiles.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) =>
              Text('Error: $e', style: TextStyle(color: p.accentErr)),
          data: (list) => list.isEmpty
              ? Text('No saved accounts.', style: TextStyle(color: p.fg2))
              : Column(
                  children: [
                    for (final profile in list)
                      _ProfileRow(profile: profile, refreshKey: ref),
                  ],
                ),
        ),
      ]),
    );
  }

  Future<String?> _promptHost(BuildContext context) async {
    final ctl = TextEditingController();
    return showDialog<String>(
        context: context,
        builder: (_) => AlertDialog(
              title: const Text('Add account for host'),
              content: TextField(
                  controller: ctl,
                  decoration: const InputDecoration(hintText: 'github.com')),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel')),
                ElevatedButton(
                    onPressed: () =>
                        Navigator.pop(context, ctl.text.trim()),
                    child: const Text('Next')),
              ],
            ));
  }
}

class _ProfileRow extends StatelessWidget {
  final AuthProfile profile;
  final WidgetRef refreshKey;

  const _ProfileRow({required this.profile, required this.refreshKey});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: p.border)),
      ),
      child: Row(children: [
        Icon(Icons.account_circle_outlined, size: 18, color: p.fg2),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                profile.username,
                style: TextStyle(color: p.fg0, fontSize: 13),
              ),
              Text(
                '${profile.host} · ${_kindLabel(profile.spec)}',
                style: TextStyle(color: p.fg2, fontSize: 11),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: () async {
            await AuthDialog.show(context, profile.host, editing: profile);
            refreshKey.invalidate(_profilesProvider);
          },
          child: const Text('Edit'),
        ),
        TextButton(
          onPressed: () async {
            final ok = await ConfirmDialog.show(context,
                title: 'Delete account',
                body: 'Remove saved account ${profile.username} '
                    '(${profile.host})?',
                confirmLabel: 'Delete',
                dangerous: true);
            if (ok) {
              await refreshKey.read(authProfileStoreProvider).delete(profile.id);
              // Drop any per-repo bindings that pointed at this profile so
              // subsequent operations don't try to resolve a deleted id.
              final notifier = refreshKey.read(appSettingsProvider.notifier);
              final current = refreshKey
                  .read(appSettingsProvider)
                  .authRepoBindings
                  .entries
                  .where((e) => e.value == profile.id)
                  .map((e) => e.key)
                  .toList();
              for (final repoId in current) {
                await notifier.setAuthBinding(repoId, null);
              }
              refreshKey.invalidate(_profilesProvider);
            }
          },
          child: const Text('Delete'),
        ),
        TextButton(
          onPressed: () async {
            final result = await Process.run(
                'git', ['ls-remote', 'https://${profile.host}'],
                runInShell: true);
            final ok = result.exitCode == 0;
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(ok
                    ? 'OK: ${profile.host} reachable'
                    : 'Failed: ${result.stderr}'),
              ));
            }
          },
          child: const Text('Test'),
        ),
      ]),
    );
  }

  String _kindLabel(AuthSpec s) {
    return switch (s) {
      AuthHttpsPat() => 'HTTPS PAT',
      AuthHttpsBasic() => 'HTTPS Basic',
      AuthSsh() => 'SSH Key',
      AuthGitHubOauth() => 'GitHub OAuth',
      AuthSystemDefault() => 'System default',
    };
  }
}
