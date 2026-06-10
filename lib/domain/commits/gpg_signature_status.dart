enum GpgSignatureStatus {
  good,
  bad,
  unknownValidity,
  expiredSignature,
  expiredKey,
  revokedKey,
  missingKey,
  unsigned;

  static GpgSignatureStatus fromGitCode(String code) {
    return switch (code) {
      'G' => GpgSignatureStatus.good,
      'B' => GpgSignatureStatus.bad,
      'U' => GpgSignatureStatus.unknownValidity,
      'X' => GpgSignatureStatus.expiredSignature,
      'Y' => GpgSignatureStatus.expiredKey,
      'R' => GpgSignatureStatus.revokedKey,
      'E' => GpgSignatureStatus.missingKey,
      'N' => GpgSignatureStatus.unsigned,
      _ => GpgSignatureStatus.unsigned,
    };
  }

  String get label {
    return switch (this) {
      GpgSignatureStatus.good => 'Verified',
      GpgSignatureStatus.bad => 'Bad signature',
      GpgSignatureStatus.unknownValidity => 'Unknown signer',
      GpgSignatureStatus.expiredSignature => 'Expired signature',
      GpgSignatureStatus.expiredKey => 'Expired key',
      GpgSignatureStatus.revokedKey => 'Revoked key',
      GpgSignatureStatus.missingKey => 'Missing key',
      GpgSignatureStatus.unsigned => 'Unsigned',
    };
  }

  bool get hasProblem {
    return switch (this) {
      GpgSignatureStatus.good || GpgSignatureStatus.unsigned => false,
      _ => true,
    };
  }
}
