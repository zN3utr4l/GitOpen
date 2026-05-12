import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/git/auth_spec.dart';
import '../../application/providers.dart';

class AuthDialog extends ConsumerStatefulWidget {
  final String host;
  const AuthDialog({super.key, required this.host});

  static Future<AuthSpec?> show(BuildContext context, String host) {
    return showDialog<AuthSpec>(context: context, builder: (_) => AuthDialog(host: host));
  }

  @override
  ConsumerState<AuthDialog> createState() => _AuthDialogState();
}

class _AuthDialogState extends ConsumerState<AuthDialog> with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _userCtl = TextEditingController();
  final _tokenCtl = TextEditingController();
  final _sshPathCtl = TextEditingController();
  bool _save = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: widget.host == 'github.com' ? 3 : 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    final isGitHub = widget.host == 'github.com';
    return Dialog(
      backgroundColor: const Color(0xFF1F1F23),
      child: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Authentication required for ${widget.host}',
                  style: const TextStyle(color: Color(0xFFD4D4D4), fontSize: 14, fontWeight: FontWeight.w600)),
            ),
            TabBar(controller: _tabs, tabs: [
              const Tab(text: 'HTTPS Token'),
              const Tab(text: 'SSH Key'),
              if (isGitHub) const Tab(text: 'GitHub Login'),
            ]),
            SizedBox(
              height: 240,
              child: TabBarView(controller: _tabs, children: [
                _httpsTab(),
                _sshTab(),
                if (isGitHub) _githubTab(),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                Checkbox(value: _save, onChanged: (v) => setState(() => _save = v ?? true)),
                const Text('Save for this host', style: TextStyle(color: Color(0xFFB8B8BC))),
                const Spacer(),
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                const SizedBox(width: 8),
                ElevatedButton(onPressed: _onSubmit, child: const Text('Connect')),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _httpsTab() => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          TextField(controller: _userCtl, decoration: const InputDecoration(labelText: 'Username')),
          const SizedBox(height: 12),
          TextField(controller: _tokenCtl, obscureText: true, decoration: const InputDecoration(labelText: 'Personal Access Token')),
        ]),
      );

  Widget _sshTab() => Padding(
        padding: const EdgeInsets.all(16),
        child: TextField(controller: _sshPathCtl, decoration: const InputDecoration(labelText: 'Path to private key (e.g. ~/.ssh/id_ed25519)')),
      );

  Widget _githubTab() => const Padding(
        padding: EdgeInsets.all(16),
        child: Text('GitHub Device Flow login (wired in Sub-slice 2C).',
            style: TextStyle(color: Color(0xFFB8B8BC))),
      );

  Future<void> _onSubmit() async {
    AuthSpec? spec;
    if (_tabs.index == 0) {
      if (_userCtl.text.isEmpty || _tokenCtl.text.isEmpty) return;
      spec = AuthHttpsPat(username: _userCtl.text, token: _tokenCtl.text);
    } else if (_tabs.index == 1) {
      if (_sshPathCtl.text.isEmpty) return;
      spec = AuthSsh(privateKeyPath: _sshPathCtl.text);
    } else {
      // GitHub tab — wired in 2C
      return;
    }
    if (_save) await ref.read(credentialsStoreProvider).put(widget.host, spec);
    if (mounted) Navigator.pop(context, spec);
  }
}
