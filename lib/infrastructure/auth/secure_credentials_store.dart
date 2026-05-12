import 'dart:convert';

import '../../application/auth/credentials_store.dart';
import '../../application/git/auth_spec.dart';
import 'dpapi_storage.dart';

/// DPAPI-backed implementation of [CredentialsStore].
///
/// Each auth entry is stored under key `gitopen:auth:<host>`.
/// Because [DpapiStorage] exposes no "enumerate all keys" API, a separate
/// index entry is kept under `gitopen:auth:__index__` as a JSON array of
/// host strings.  The index is updated atomically with every [put]/[delete].
class SecureCredentialsStore implements CredentialsStore {
  static const _prefix = 'gitopen:auth:';
  static const _indexKey = '${_prefix}__index__';

  final DpapiStorage _storage;

  SecureCredentialsStore({DpapiStorage? storage})
      : _storage = storage ?? DpapiStorage.instance;

  // ---------------------------------------------------------------------------
  // CredentialsStore interface
  // ---------------------------------------------------------------------------

  @override
  Future<AuthSpec?> get(String host) async {
    final json = await _storage.read('$_prefix$host');
    if (json == null) return null;
    return _decode(json);
  }

  @override
  Future<void> put(String host, AuthSpec spec) async {
    await _storage.write('$_prefix$host', _encode(spec));
    await _indexAdd(host);
  }

  @override
  Future<void> delete(String host) async {
    await _storage.delete('$_prefix$host');
    await _indexRemove(host);
  }

  @override
  Future<List<String>> hosts() async {
    final raw = await _storage.read(_indexKey);
    if (raw == null) return const [];
    final list = (jsonDecode(raw) as List<dynamic>).cast<String>();
    return list;
  }

  // ---------------------------------------------------------------------------
  // Index helpers
  // ---------------------------------------------------------------------------

  Future<List<String>> _readIndex() async {
    final raw = await _storage.read(_indexKey);
    if (raw == null) return [];
    return (jsonDecode(raw) as List<dynamic>).cast<String>();
  }

  Future<void> _writeIndex(List<String> index) async {
    await _storage.write(_indexKey, jsonEncode(index));
  }

  Future<void> _indexAdd(String host) async {
    final index = await _readIndex();
    if (!index.contains(host)) {
      index.add(host);
      await _writeIndex(index);
    }
  }

  Future<void> _indexRemove(String host) async {
    final index = await _readIndex();
    if (index.remove(host)) {
      await _writeIndex(index);
    }
  }

  // ---------------------------------------------------------------------------
  // Encode / decode
  // ---------------------------------------------------------------------------

  String _encode(AuthSpec spec) {
    final map = switch (spec) {
      AuthHttpsPat() => {
          'kind': 'pat',
          'username': spec.username,
          'token': spec.token,
        },
      AuthHttpsBasic() => {
          'kind': 'basic',
          'username': spec.username,
          'password': spec.password,
        },
      AuthSsh() => {
          'kind': 'ssh',
          'keyPath': spec.privateKeyPath,
          'passphrase': spec.passphrase,
        },
      AuthGitHubOauth() => {'kind': 'github', 'token': spec.accessToken},
      AuthSystemDefault() => {'kind': 'system'},
    };
    return jsonEncode(map);
  }

  AuthSpec _decode(String json) {
    final m = jsonDecode(json) as Map<String, dynamic>;
    switch (m['kind']) {
      case 'pat':
        return AuthHttpsPat(
          username: m['username'] as String,
          token: m['token'] as String,
        );
      case 'basic':
        return AuthHttpsBasic(
          username: m['username'] as String,
          password: m['password'] as String,
        );
      case 'ssh':
        return AuthSsh(
          privateKeyPath: m['keyPath'] as String,
          passphrase: m['passphrase'] as String?,
        );
      case 'github':
        return AuthGitHubOauth(m['token'] as String);
      case 'system':
        return const AuthSystemDefault();
      default:
        throw FormatException('Unknown auth kind: ${m['kind']}');
    }
  }
}
