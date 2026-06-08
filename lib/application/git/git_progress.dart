final class GitProgress {
  const GitProgress({
    required this.phase,
    required this.rawLine,
    this.fraction,
  });
  final String phase;
  final double? fraction;
  final String rawLine;
}
