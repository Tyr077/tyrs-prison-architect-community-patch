# Tyr's Prison Architect Community Patch

Bug fixes for Prison Architect 1 that cannot be done with mods, delivered as a
small patcher that edits your own copy of the game.

This project does not contain or distribute the game. The patcher only changes
a few hundred bytes inside the `Prison Architect64.exe` you already own, keeps a
backup, and can put everything back.

Works with the Steam "Sunset Update" build, which is the final version of the
game. Other builds (GOG, Epic, older versions) are detected and refused; see
"Unsupported build" below.

## Install

1. Download `TyrsPAPatch.exe` from the latest release.
2. Close Prison Architect.
3. Run `TyrsPAPatch.exe`. It finds the game in your Steam library, shows whether
   you are patched, and has an **Apply patch** button. That is it.

Windows SmartScreen will warn the first time because the file is not
code-signed. Click **More info**, then **Run anyway**. Each release lists the
SHA256 of the download so you can check it.

If Steam ever runs "Verify integrity of game files", it restores the original
executable. Just run the patcher again and click Apply.

**Revert to original** restores the unpatched game at any time.

## Fixes included

### Gang contraband hand-off (Gangs DLC)

Symptoms: a gang member gets the contraband hand-off icon and then paces around
at speed, ignores the regime, and every guard sent to search or escort him
drops the job immediately. Related: a crooked guard who stops doing anything at
all, and hand-offs never happening again after you fire a crooked guard.

Cause: the hand-off misbehaviour state has no exit on the prisoner side, and
the crooked guard's routine that is supposed to end it gives up on a regime
change, a gang member who no longer exists, or a guard who was fired or
killed. Nothing ever clears those, so prisoners are stranded permanently.

Fix: the prisoner now checks each tick that the hand-off is still valid (he is
the chosen gang member, the guard still exists, the regime allows it) and
clears himself if not. The guard routine clears stale gang members and aborts
cleanly on regime changes. The system re-picks a guard when the old one is
gone. Crooked guards, bribes and hand-offs keep working.

## Unsupported build

The patcher checks the game file before touching anything. If it says
"Unsupported game build", it will not change your game. Click **Copy file
hash** and open an issue with the hash and where you bought the game. If enough
people have that build it can be supported.

## Reporting other bugs

Fixes are considered for reproducible engine bugs that mods cannot reach.
Please include a save file that shows the bug, what you expected to happen, and
what happens instead.

## For the technically inclined

- `patches/*.patch.json` are the actual patches: file offsets, the bytes
  expected there, and the replacement bytes. The patcher embeds these.
- `scripts/Apply-ExePatch.ps1` applies a patch file from PowerShell without the
  GUI. `TyrsPAPatch.exe` also accepts `--status`, `--apply` and `--revert`. It is a
  windowed program, so a console does not wait for it; scripts should use
  `Start-Process -Wait` or the PowerShell script above.
- `scripts/Build-Patch.ps1` regenerates the hand-off patch from the addresses
  in the script, and `tools/ghidra-scripts/` are the Ghidra scripts used to
  find them. Full technical notes are in `docs/gang-handoff.md`.
- Build the patcher with `dotnet build -c Release` in `patcher/`. It targets
  .NET Framework 4.8, which is already part of Windows 10 and 11.

## Licence

MIT. See `LICENSE`.
