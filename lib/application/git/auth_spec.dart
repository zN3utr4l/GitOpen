sealed class AuthSpec {
  const AuthSpec();
}

final class AuthHttpsPat extends AuthSpec {
  const AuthHttpsPat({required this.username, required this.token});
  final String username;
  final String token;
}

final class AuthHttpsBasic extends AuthSpec {
  const AuthHttpsBasic({required this.username, required this.password});
  final String username;
  final String password;
}

final class AuthSsh extends AuthSpec {
  const AuthSsh({required this.privateKeyPath, this.passphrase});
  final String privateKeyPath;
  final String? passphrase;
}

final class AuthGitHubOauth extends AuthSpec {
  const AuthGitHubOauth(this.accessToken);
  final String accessToken;
}

final class AuthSystemDefault extends AuthSpec {
  const AuthSystemDefault();
}
