# GitOpen

Cross-platform open-source desktop git client built on .NET 8 + Photino.Blazor.
Inspired by Fork. Targets Windows and Ubuntu.

> **Status:** Slice 1 (read-only viewer) under development. See
> `docs/superpowers/specs/` and `docs/superpowers/plans/` for roadmap.

## Build and run

Prerequisites:
- .NET 8 SDK
- `git` CLI on `PATH` (Git for Windows on Windows; `apt install git` on Ubuntu)
- On Linux: `sudo apt install libwebkit2gtk-4.1-0`

```bash
dotnet build GitOpen.sln
dotnet run --project src/GitOpen.Ui
```

## Tests

```bash
dotnet test GitOpen.sln
```

## License

MIT
