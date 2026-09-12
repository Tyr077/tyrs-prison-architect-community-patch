# Test build

`TyrsPAPatch.exe` in this folder is a build of whatever is on the `testing`
branch right now. It is here so testers can download and run it without
building anything.

**It is not a release.** Releases are attached to the GitHub Releases page and
only ever come from `main`. Everything here is waiting to be confirmed in a real
prison. If you are not testing, use the latest release instead.

## Download

Open [`TyrsPAPatch.exe`](TyrsPAPatch.exe) on GitHub and click the download
button. Windows SmartScreen will warn because the file is not code-signed:
**More info**, then **Run anyway**.

Your game file is backed up to `Prison Architect64.exe.orig` before anything is
written, and **Revert to original** puts it back at any time. If a test build
ever leaves the game in a strange state, revert, or let Steam verify the game
files.

## This build

| | |
|---|---|
| Version | 1.6.0 |
| SHA-256 | `5eb8efe06405035ec6537739b697691c06fb19059d351dff1656fe5be2bbea67` |
| Branch | `testing` |

Full notes for what is in it: [`docs/release-notes-v1.6.0.md`](../docs/release-notes-v1.6.0.md).

## What needs confirming in 1.6.0

**Exercise on equipment counts towards the Health grade.** Build a gym with
equipment (weights bench, treadmill, punch bag, ...) that prisoners reach
without a yard to jog in, let them use it, and watch the "% of stay exercising"
line on the Grading tab of a prisoner's profile actually move. Before this fix
it stayed at zero unless the prisoner jogged laps around a Yard room. Also worth
a look: a prison-labour room still credits work experience as it did, since that
case was deliberately left alone.

**The patcher window.** Two behaviours changed and are the most likely place for
a surprise:

- **Apply selection** now *removes* fixes you untick, as well as installing the
  ones you tick. Previously unticking did nothing and the only way to remove a
  fix was to revert everything.
- **Revert to original** ignores the tick boxes entirely and always restores the
  unpatched file.

Also worth checking: your ticks and the expanded/collapsed groups come back next
time you open it (they live in `%AppData%\TyrsPAPatch\settings.json`; delete that
file to get the defaults back), and each line shows whether that fix is installed
in your game.

## Reporting

Please say which build you used (the SHA-256 above), what you did, what you
expected and what happened. A save file that shows the problem is worth more than
anything else.

## Rebuilding it yourself

`dotnet build -c Release` in `patcher/`, then copy
`patcher/bin/Release/net48/TyrsPAPatch.exe` here. The build is deterministic, so
a clean build of the same commit reproduces the hash above exactly — as long as
the sources have the line endings git checks out, since those are part of what
the compiler hashes.
