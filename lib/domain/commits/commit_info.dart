import 'package:equatable/equatable.dart';

import 'package:gitopen/domain/commits/commit_sha.dart';
import 'package:gitopen/domain/commits/commit_signature.dart';
import 'package:gitopen/domain/commits/gpg_signature_status.dart';

final class CommitInfo extends Equatable {
  const CommitInfo({
    required this.sha,
    required this.parentShas,
    required this.author,
    required this.committer,
    required this.summary,
    required this.message,
    this.signatureStatus = GpgSignatureStatus.unsigned,
  });
  final CommitSha sha;
  final List<CommitSha> parentShas;
  final CommitSignature author;
  final CommitSignature committer;
  final String summary;
  final String message;
  final GpgSignatureStatus signatureStatus;

  @override
  List<Object?> get props => [
    sha,
    parentShas,
    author,
    committer,
    summary,
    message,
    signatureStatus,
  ];
}
