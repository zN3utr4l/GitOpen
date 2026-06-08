/// Pre-computed decoration for a single ref pill in the commit row.
///
/// When a local branch and one (or more) of its remote-tracking branches
/// resolve to the same commit, they are merged into a single decoration
/// with [syncedRemotes] listing the remote-side names. The pill widget
/// uses that to render the local name + a sync indicator + the remote
/// host(s) rather than two stacked pills.
class RefDecoration {

  const RefDecoration({
    required this.name,
    required this.isRemote,
    required this.isTag,
    required this.isCurrent,
    this.syncedRemotes = const [],
  });
  final String name;
  final bool isRemote;
  final bool isTag;
  final bool isCurrent;
  final List<String> syncedRemotes;

  bool get isSynced => syncedRemotes.isNotEmpty;
}
