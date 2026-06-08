final class CommitRequest {

  const CommitRequest({
    required this.message,
    this.amend = false,
    this.signOff = false,
    this.authorName,
    this.authorEmail,
  });
  final String message;
  final bool amend;
  final bool signOff;
  final String? authorName;
  final String? authorEmail;
}
