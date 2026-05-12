import '../git/auth_spec.dart';

abstract interface class CredentialsStore {
  Future<AuthSpec?> get(String host);
  Future<void> put(String host, AuthSpec spec);
  Future<void> delete(String host);
  Future<List<String>> hosts();
}
