# In-game test harness

Loads a save into a scratch copy of the game, lets it run, and checks the
autosave it writes. It covers fixes whose outcome is visible in the save file
or in a Lua mod's debug output. Anything that needs mouse or keyboard input
(Warden Mode, Escape Mode, hold to fire) still needs a person.

## Files

| file | what |
|---|---|
| `Run-InGameTest.ps1` | `Invoke-InGameRun`: prepare the scratch game, apply a patch selection, stage the save, launch with `--continuelastsave`, wait for autosaves, collect results, restore the user files |
| `Parse-PrisonSave.ps1` | `ConvertFrom-PrisonSave`, `Get-PrisonObjects`, `Get-PrisonValue`, `Get-PrisonSummary`: the plain-text save as nested hashtables |
| `tests\*.ps1` | one scenario each; prints PASS/FAIL and exits 0/1 |
| `results\<name>-<stamp>\` | per run: `autosave.prison`, `debug.txt`, `run.json`, the user files as they were before the run (gitignored) |

## How a run works

1. Refuses to start while `Prison Architect64` is running.
2. Scratch game at `D:\projects\tools\pa-test\game`: a copy of the Steam
   install without the launcher, with the original exe kept as
   `Prison Architect64.exe.orig` and a `steam_appid.txt` (233450) so the
   Steam API initialises from the running Steam client instead of refusing
   to start outside the library. Steam must be running.
3. The exe is reset to the original and the patcher CLI applies the
   selection: `original`, `fixes` or `fixes+tweaks`. The result hash is in
   `run.json`, so a run always says which build it tested.
4. The save is copied to `saves\tyrs-test.prison` in the game's user folder
   and `continue_game.json` is pointed at it. `-TimeWarp` rewrites the
   `TimeWarpFactor` header (game minutes per real second; 0.125 is the
   SlowTime mutator, 1.25 is ten times that).
5. `preferences.txt` gets windowed 1600x900, autosave every minute, and the
   `Mods` line for any `-Mod` folders (copied into `mods\` by folder name,
   enabled by the manifest `Name`).
6. The game is launched with `--continuelastsave`. The runner watches
   `debug.txt` for `Loading map from '...tyrs-test.prison'`, then counts
   autosaves by the write time of `saves\autosave.prison` (the log's
   `Save completed` lines are only a floor: the game stops writing debug.txt
   after a few minutes of play while it keeps autosaving) until `-Autosaves`
   are seen or `-MaxMinutes` pass.
7. The game is killed, `autosave.prison` and `debug.txt` are copied to the
   results folder, and `preferences.txt` and `continue_game.json` are put
   back, also when the run fails.

The user folder is shared with the real game, so do not play while a test
runs.

## Writing a test

```powershell
. (Join-Path $PSScriptRoot '..\Run-InGameTest.ps1')
. (Join-Path $PSScriptRoot '..\Parse-PrisonSave.ps1')
$before = ConvertFrom-PrisonSave $Save
$r = Invoke-InGameRun -Save $Save -Selection fixes -Autosaves 3 -TimeWarp 1.25 -Name 'my-test'
if (-not $r.Ok) { "FAIL: $($r.Note)"; exit 1 }
$after = ConvertFrom-PrisonSave $r.Autosave
$prisoners = Get-PrisonObjects $after -Type Prisoner
```

Objects are the entries of the `Objects` block; every scalar is a string
(`$p['Pos.x']`, `$p.Bio.Served`, `$p.StatusEffects.surrendered.Charge`), so
use `ToDouble` for arithmetic. Compare by `Id.u`, which survives reloads.

Run a test with `-Selection original` as well when the unpatched behaviour is
part of the claim; the keycard test does this.

A Lua observer mod is the other assertion channel: `Game.DebugOut` lines land
in `debug.txt`, which the run copies. Pass the mod folder with `-Mod`.

## Tests

| test | save | checks |
|---|---|---|
| `load-smoke.ps1` | keycardtest3local.prison | the save loads, autosaves, and the clock advances |
| `keycard-released-prisoners.ps1` | keycardtest3local.prison | prisoners whose sentence is served leave (with `-Selection original`: they stay stuck) |
| `visitor-booth-facing.ps1` | built from base3z.prison | booths facing up in a room split into a prisoner half and a VisitorOnly visitor half: a visit starts (fixes) or never does (original) |
| `exercise-grading.ps1` | built from base3z.prison | the Yard retyped so nobody can jog for credit; bench users gain an Exercise counter (fixes) or nobody does (original); runs both builds. 2026-09-16: original 0 gains, fixes 9 (4 confirmed on a bench); the PASS line was masked by a scoring bug since fixed, rerun pending |
| `shop-front.ps1` | built from base3z.prison | the shop zoned MinSecOnly with most prisoners recategorised Normal, so only MinSec shopkeepers may enter: non-MinSec shoppers and revenue appear (fixes) or not (original); runs both builds. Not yet run in this form (StaffOnly zoning starved the shop of its prisoner staff; shopping starts about 13:00) |
| `armed-guard-warnings.ps1` | built from RIOT(ROCKHARD).prison | riot with low staff morale (pay factor 0, StaffMorale 10; the game holds it near 14%): peak count of prisoners with the surrendered effect, clearly higher with the fix; runs both builds. 2026-09-16: original peak 5; the fixed run had 10 surrendered and 2 rioting (vs 8) at its first autosave, then the game closed the map on its own about an hour later (orderly exit, code 18, no crash dump, cause unknown; failure conditions are on in preferences), so the run counts as unfinished |

## Building a scenario save

Saves are plain text, so a test can build its scenario instead of needing a
hand-made save. `visitor-booth-facing.ps1` shows the pattern: remove objects
by their one-line entries, add new ones after the `Objects` `Size` line with
fresh `Id.i`/`Id.u` values (bump `Size` and `ObjectId.next`), and change
cells in the `Cells` block (4-space `BEGIN "x y"` lines; the same keys appear
again in later blocks, so match on `Mat`). The game recomputes sectors when it
loads changed walls, so anything that needs a sector setting (`Zone
VisitorOnly` on a sector entry) is done in a second stage: load the edited
save once for a few game minutes, take that autosave, edit the sector entry
by its rectangle, and use the result as the test save. A .NET regex `$` does
not match before a carriage return, so anchor line ends with a negated
character class for CR and LF instead of `$` on these CRLF files.

Every autosave of a run is kept as `autosave-<n>.prison` in the results
folder, so a test can read the timeline, not only the end state.

## Where things stand (2026-09-16 evening)

Proven in the game by this harness: keycard released prisoners, visitor booths
facing up, exercise grading (see the scoring note in the table). Pending: the
shop test in its MinSec-only form has not been run; the warnings test needs
its fixed run repeated (turn off failure conditions in preferences.txt for the
run, or read the Events block of the last autosave to see what ended it); the
intake test is not staged because the road stop's per-category toggles are
not found in the save (the accepted set comes from a byte array at the stop
record `+0x50`; no registered name seen). Not testable here: weapon effects,
Escape Mode Freefire, hold to fire, disarmed armed guards, the three tweaks.

## Limits

- Real time. Even at `-TimeWarp 1.25` an in-game hour is about a minute.
- The scenario has to be in the save already, hand-built or edited in by the
  test; Lua can spawn objects but not start fights or give orders.
- Randomness: one run shows something happened, not that it always does.
- Needs a desktop session and the GPU; no headless mode, no CI.
- The built patcher decides what `fixes` means. Rebuild it after changing a
  patch file, or the run tests the previous version.
