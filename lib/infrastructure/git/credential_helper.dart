import 'dart:io';

import 'package:path/path.dart' as p;

import '../../application/git/auth_spec.dart';

/// Produces environment variables for a git subprocess to satisfy credential
/// prompts without blocking on interactive TTY input.
///
/// For HTTPS auth (PAT / Basic / GitHub OAuth) it writes the username and
/// password to temp files and installs a tiny GIT_ASKPASS script that echoes
/// the correct value based on git's prompt string.
///
/// For SSH it sets GIT_SSH_COMMAND with the specific key file.
///
/// Callers MUST call the returned `dispose` function after the subprocess
/// finishes (in a `finally` block) so the temp files are cleaned up.
class CredentialHelper {
  /// Returns `({env, dispose})` where `env` should be merged into the
  /// subprocess environment and `dispose` deletes any temp files created.
  ///
  /// [host] is informational only (not used in the current Slice-2 approach).
  static Future<({Map<String, String> env, void Function() dispose})> setup(
      AuthSpec? auth, String host) async {
    if (auth == null || auth is AuthSystemDefault) {
      return (env: <String, String>{}, dispose: () {});
    }

    if (auth is AuthSsh) {
      return (
        env: {
          'GIT_SSH_COMMAND':
              'ssh -i ${auth.privateKeyPath} -F /dev/null -o IdentitiesOnly=yes',
        },
        dispose: () {},
      );
    }

    // HTTPS or GitHub OAuth — produce an ASKPASS helper script.
    final tmp = Directory.systemTemp.createTempSync('gitopen-askpass-');
    final usrFile = File(p.join(tmp.path, 'user.txt'));
    final pwdFile = File(p.join(tmp.path, 'pass.txt'));
    final scriptFile = File(
        p.join(tmp.path, Platform.isWindows ? 'askpass.bat' : 'askpass.sh'));

    String username;
    String secret;
    if (auth is AuthHttpsPat) {
      username = auth.username;
      secret = auth.token;
    } else if (auth is AuthHttpsBasic) {
      username = auth.username;
      secret = auth.password;
    } else if (auth is AuthGitHubOauth) {
      username = 'x-access-token';
      secret = auth.accessToken;
    } else {
      // Unknown HTTPS variant — fall through to system default.
      return (env: <String, String>{}, dispose: () {});
    }

    await usrFile.writeAsString(username);
    await pwdFile.writeAsString(secret);

    if (Platform.isWindows) {
      // The prompt arg contains "ame" for "Username" and not for "Password".
      await scriptFile.writeAsString(
          '@echo off\r\n'
          'echo %1 | findstr /i "ame" >nul && type "${usrFile.path}" || type "${pwdFile.path}"\r\n');
    } else {
      await scriptFile.writeAsString('#!/bin/sh\n'
          'case "\$1" in\n'
          '  *[Uu]sername*) cat "${usrFile.path}" ;;\n'
          '  *) cat "${pwdFile.path}" ;;\n'
          'esac\n');
      await Process.run('chmod', ['+x', scriptFile.path]);
    }

    void dispose() {
      try {
        tmp.deleteSync(recursive: true);
      } catch (_) {}
    }

    return (
      env: {
        'GIT_ASKPASS': scriptFile.path,
        'GIT_TERMINAL_PROMPT': '0',
      },
      dispose: dispose,
    );
  }
}
