import 'package:flutter_test/flutter_test.dart';
import 'package:gitopen/domain/commits/gpg_signature_status.dart';

void main() {
  test('maps git %G? codes to signature statuses', () {
    expect(GpgSignatureStatus.fromGitCode('G'), GpgSignatureStatus.good);
    expect(GpgSignatureStatus.fromGitCode('B'), GpgSignatureStatus.bad);
    expect(
      GpgSignatureStatus.fromGitCode('U'),
      GpgSignatureStatus.unknownValidity,
    );
    expect(
      GpgSignatureStatus.fromGitCode('X'),
      GpgSignatureStatus.expiredSignature,
    );
    expect(GpgSignatureStatus.fromGitCode('Y'), GpgSignatureStatus.expiredKey);
    expect(GpgSignatureStatus.fromGitCode('R'), GpgSignatureStatus.revokedKey);
    expect(GpgSignatureStatus.fromGitCode('E'), GpgSignatureStatus.missingKey);
    expect(GpgSignatureStatus.fromGitCode('N'), GpgSignatureStatus.unsigned);
    expect(GpgSignatureStatus.fromGitCode('?'), GpgSignatureStatus.unsigned);
  });
}
