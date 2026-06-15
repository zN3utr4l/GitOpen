/// A commit co-author parsed from a `Co-authored-by:` message trailer.
typedef CoAuthor = ({String name, String email});

// Matches a `Co-authored-by: Name <email>` trailer line. Case-insensitive on
// the key; the name is everything up to the first `<`, the email everything
// between `<` and `>`. No end anchor, so a trailing CR (CRLF messages) or
// extra text after `>` does not break the match.
final RegExp _coAuthorTrailer = RegExp(
  r'^[ \t]*co-authored-by:[ \t]*(.*?)<([^>\n]+)>',
  caseSensitive: false,
  multiLine: true,
);

/// Parses `Co-authored-by:` trailers from a commit [message].
///
/// De-duplicated by email (case-insensitive), preserving first-seen order.
/// Trailers without an `<email>` are ignored.
List<CoAuthor> parseCoAuthors(String message) {
  final seen = <String>{};
  final result = <CoAuthor>[];
  for (final match in _coAuthorTrailer.allMatches(message)) {
    final name = match.group(1)!.trim();
    final email = match.group(2)!.trim();
    if (email.isEmpty) continue;
    if (!seen.add(email.toLowerCase())) continue;
    result.add((name: name, email: email));
  }
  return result;
}
