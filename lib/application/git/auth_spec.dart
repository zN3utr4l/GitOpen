sealed class AuthSpec {
  const AuthSpec();
}

final class AuthHttpsPat extends AuthSpec {
  final String username;
  final String token;
  const AuthHttpsPat({required this.username, required this.token});
}

final class AuthHttpsBasic extends AuthSpec {
  final String username;
  final String password;
  const AuthHttpsBasic({required this.username, required this.password});
}

final class AuthSsh extends AuthSpec {
  final String privateKeyPath;
  final String? passphrase;
  const AuthSsh({required this.privateKeyPath, this.passphrase});
}

final class AuthGitHubOauth extends AuthSpec {
  final String accessToken;
  const AuthGitHubOauth(this.accessToken);
}

final class AuthSystemDefault extends AuthSpec {
  const AuthSystemDefault();
}
