# In-game test harness

Loads a save into a scratch copy of the game, lets it run, and checks the
autosaves it writes. It covers fixes whose outcome shows in the save file or in
a Lua mod's saved fields. Anything that needs mouse or keyboard input (Warden
Mode, Escape Mode, hold to fire) still needs a person.

## Requirements

- Windows desktop session with the GPU; no headless mode, no CI.
- Steam running, and the Steam install of the game (the scratch copy at
  `D:\projects\tools\pa-test\game` is made from it on first use).
- The built patcher at `patcher\bin\Release\net48\TyrsPAPatch.exe`. It decides
  what `fixes` means, so rebuild it after changing a patch file.
- Prison Architect closed. The harness shares the game's user folder, so do
  not play while a test runs.

## Files

| file | what |
|---|---|
| `Run-InGameTest.ps1` | `Invoke-InGameRun`: one game run, returns a result object |
| `Parse-PrisonSave.ps1` | `ConvertFrom-PrisonSave`, `Get-PrisonObjects`, `Get-PrisonValue`, `Get-PrisonSummary` |
| `Run-Queue.ps1` | runs several tests one after another, unattended |
| `tests\*.ps1` | one scenario each; prints PASS/FAIL/NOTE lines, exits 0/1 |
| `results\` | per run: autosaves, `debug.txt`, `run.json` (gitignored) |

## Running

Run a test directly, or queue several:

```powershell
.\tests\exercise-grading.ps1
.\tests\gunfire-surrender.ps1 -Speed 1 -Repeat 3
.\Run-Queue.ps1 'exercise-grading' 'gunfire-surrender -Repeat 3'
```

`Run-Queue.ps1` takes test names (without `.ps1`), each optionally followed by
its arguments in one quoted entry. Every test runs in its own PowerShell
process; logs go to `results\queue-<stamp>\` and `summary.txt` collects each
test's exit code, duration and PASS/FAIL/NOTE lines. For a long queue start it
with `Start-Process powershell -WindowStyle Hidden`.

Common test parameters (each test sets its own defaults):

| parameter | meaning |
|---|---|
| `-Save` | save file to load |
| `-Selection` | build(s) to run: `original`, `fixes`, `fixes+tweaks`; tests that compare builds also take `both` (see each test's `param` block) |
| `-Speed 0..4` | in-game speed key pressed after the load: 1 = x1, 2 = x2, 3 = x5, 4 = x10; 0 leaves normal speed |
| `-Autosaves` | autosaves to wait for (one per real minute) |
| `-TimeWarp` | clock rate written into the save; tests use 1.0 |
| `-Repeat` | runs per build, for tests that compare averages |
| `-DryRun` | build the scenario save without launching the game |

Stay within the four game speeds. Autosaves stay one per real minute whatever
the speed, so tests that read a timeline use a lower speed.

## Adding a test

Create `tests\<name>.ps1` that builds or picks a save, calls `Invoke-InGameRun`
and prints PASS or FAIL:

```powershell
. (Join-Path $PSScriptRoot '..\Run-InGameTest.ps1')
. (Join-Path $PSScriptRoot '..\Parse-PrisonSave.ps1')
$r = Invoke-InGameRun -Save $Save -Selection fixes -Autosaves 3 -TimeWarp 1.0 -Speed 3 -Name 'my-test'
if (-not $r.Ok) { "FAIL: $($r.Note)"; exit 1 }
$after = ConvertFrom-PrisonSave $r.Autosave
$prisoners = Get-PrisonObjects $after -Type Prisoner
```

Other `Invoke-InGameRun` parameters:

- `-Without <patch id>` applies the selection, then removes that one patch, to
  compare a build with and without a single fix or tweak.
- `-NoFailureConditions` turns failure conditions off for the run.
- `-Mod <folder>` installs and enables a Lua mod for the run.
- `-MaxMinutes` gives up after that many real minutes (default 15).

Save values parse as strings; use `ToDouble` for arithmetic and compare objects
by `Id.u`. Every autosave of a run is kept as `autosave-<n>.prison`, so a test
can read a timeline. Saves are plain text, so a test can edit its scenario into
a copy of a save; `visitor-booth-facing.ps1` shows the pattern. The save files
use CRLF, so a .NET regex `$` will not match at line ends; anchor on a negated
`[^\r\n]` class instead. A Lua observer mod (`-Mod`) can keep results in its
own fields, which the game writes into the save;
`tools\testmods\fire-rate-observer` is the example.

Run the unpatched build too (`-Selection original` or `both`) when the claim is
that the fix changes something.

## Status (2026-09-25)

| test | status |
|---|---|
| `load-smoke` | works: save loads, autosaves, clock advances |
| `speed-calibration` | works: measured x1, x2, x5, x10 |
| `keycard-released-prisoners` | proven |
| `visitor-booth-facing` | proven |
| `exercise-grading` | proven |
| `direction-save` | proven |
| `lua-status-effects` | proven |
| `pc-shared-zones` | proven (work and programs) |
| `gunfire-surrender` | fire rate proven; surrender weak (passed once, failed once) |
| `armed-guard-warnings` | weak indication only |
| `shop-front` | failed: scenario sells nothing on either build |
| `visitor-door-access` | failed: scenario does not move the NPCs |
| intake with route categories | not staged |

Not testable here: weapon effects, Escape Mode Freefire, hold to fire,
disarmed armed guards, and the three older tweaks.

## Limits

- Real time: every run spends about 1.5 minutes loading, and autosaves, the
  only snapshots, come once per real minute.
- Randomness: one run shows something happened, not that it always does.
- The scenario has to be in the save already, hand-built or edited in by the
  test.
