import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../application/providers.dart';
import '../../theme/app_palette.dart';

class UpdatesSection extends ConsumerStatefulWidget {
  const UpdatesSection({super.key});

  @override
  ConsumerState<UpdatesSection> createState() => _UpdatesSectionState();
}

class _UpdatesSectionState extends ConsumerState<UpdatesSection> {
  bool _checking = false;
  String? _status;
  String? _updateVersion;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final s = ref.watch(appSettingsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Updates',
            style: TextStyle(
              color: p.fg0,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Switch(
                value: s.autoUpdateCheck,
                onChanged: ref.read(appSettingsProvider.notifier).setAutoUpdateCheck,
              ),
              const SizedBox(width: 12),
              Text(
                'Check for updates on startup',
                style: TextStyle(color: p.fg0, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              ElevatedButton.icon(
                icon: _checking
                    ? SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: p.fg0,
                        ),
                      )
                    : const Icon(Icons.refresh, size: 14),
                label: const Text('Check now'),
                onPressed: _checking ? null : _check,
              ),
              const SizedBox(width: 16),
              if (_status != null)
                Flexible(
                  child: Text(
                    _status!,
                    style: TextStyle(
                      color: _updateVersion != null ? p.accentCurrent : p.fg1,
                      fontSize: 13,
                    ),
                  ),
                ),
            ],
          ),
          if (_updateVersion != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.open_in_new, size: 14),
              label: const Text('Open release page'),
              onPressed: _openReleasePage,
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _check() async {
    setState(() {
      _checking = true;
      _status = null;
      _updateVersion = null;
    });
    final updater = ref.read(updaterProvider);
    try {
      const currentVersion = '0.1.0';
      final version = await updater.checkForUpdates(currentVersion);
      setState(() {
        _updateVersion = version;
        _status = version != null
            ? 'Update available: v$version'
            : 'You are up to date.';
      });
    } catch (e) {
      setState(() => _status = 'Check failed: $e');
    } finally {
      setState(() => _checking = false);
    }
  }

  Future<void> _openReleasePage() async {
    await ref.read(updaterProvider).openReleasesPage();
  }
}
