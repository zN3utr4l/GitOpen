/// Which main-area widget the shell shows.
enum ShellBody { settings, welcome, repo }

/// Picks the shell's main content.
///
/// Settings takes precedence over everything: it must be reachable even when
/// the repo catalog is empty. Otherwise an empty/unselected catalog shows the
/// welcome screen, and an active repo shows the repo body.
///
/// (Previously the empty-catalog check came first, so with zero repos the
/// Settings button toggled state but the page never showed.)
ShellBody shellBodyFor({
  required bool settingsOpen,
  required bool hasActiveRepo,
}) {
  if (settingsOpen) return ShellBody.settings;
  if (!hasActiveRepo) return ShellBody.welcome;
  return ShellBody.repo;
}
