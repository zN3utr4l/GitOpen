# Manual QA Checklist (Slice 1 — read-only viewer)

Run on both Windows and Ubuntu before each release.

## Smoke
- [ ] App launches, main window appears
- [ ] No errors in `%APPDATA%/GitOpen/logs/` (Win) or `~/.config/GitOpen/logs/` (Linux)

## Open repository
- [ ] "+" tab opens folder picker
- [ ] Selecting a folder containing `.git` adds a tab; sidebar populates
- [ ] Selecting a folder without `.git` shows an error toast (or graceful empty)

## Multiple repos
- [ ] Open 3 repos; tabs visible; clicking each switches the panel
- [ ] Close a tab via × removes it from the bar

## Commit graph
- [ ] Repo with linear history shows single lane
- [ ] Repo with branches shows multiple coloured lanes
- [ ] Scroll through 5000+ commits is fluid
- [ ] Branch and tag pills appear on the correct rows
- [ ] HEAD → marker on current branch pill

## Bottom panel
- [ ] Click a commit → Commit tab shows author, sha, full message
- [ ] Changes tab shows diff with +/- lines and hunk headers
- [ ] Binary files show "Binary file (no preview)"
- [ ] File Tree tab lists root entries; folders sort first

## Persistence
- [ ] Open 2 repos, close app, reopen — both repos reopen automatically
- [ ] Move a repo folder, reopen app — the missing repo is silently dropped (logged)

## Resilience
- [ ] Open a very large repo (10k+ commits) — initial load < 5 s
- [ ] Open an empty repo (no commits) — graph panel shows "No commits"
