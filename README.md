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

### Ranged weapon fire rate

Symptoms: assault rifles and SMGs fire one shot every two seconds, the same as
a sniper rifle, so armed guards with automatic weapons are close to useless.

Cause: after every ranged shot the game starts a two-second "reload" timer and
refuses to count the weapon's real recharge time until it expires. The old 2.7
build had no such timer. Community Lua mods work around it by zeroing the timer
every tick, which is expensive and cannot be applied to prisoners without
breaking Escape Mode.

Fix: the reload timer is no longer set after a shot, so guards and prisoners
fire at the `RechargeTime` from `materials.txt`. The Escape Mode player
attack, which relied on that timer as its only rate limit, is given a proper
rate limit based on the time since the last shot. Technical notes in
`docs/weapon-firerate.md`.
### Alert icons with custom sprite-sheet mods

Symptoms: as soon as any mod with its own `sprites.png` is enabled, many
notification icons (gang alerts, contraband, overheating, tropical fever, fallen
trees, chewed fences, CCTV misconduct, tracking belts, plumbers and repairmen on
site) draw as the wrong piece of a sprite sheet. The bakery oven glow breaks the
same way.

Cause: those icons live in the `objects_d11_2` sheet, but the code that draws
them scales their coordinates with the main object atlas. Both sheets are the
same size in a vanilla install, so the mistake is invisible until a mod makes
the atlas bigger.

Fix: the icon draw now uses the scale of the sheet the icon actually comes
from. If you use the "Alert Icons Partial Fix" mod, disable it after applying
this; its workaround would otherwise double-correct. Technical notes in
`docs/alert-icons.md`.
### Prisoner and staff directions not saved

Symptoms: direction markings you place for prisoners or staff are gone after
you load the save.

Cause: the save writer does not know how to write single-byte fields. The
directions are stored as bytes, so the key is written without a value and
dropped on load. The same happens to visitor skin and clothing colours and a
few other byte fields.

Fix: the game now writes those fields as plain numbers, which the loader
already understands. Everything stored as a byte is saved, not just the two
direction fields. First reported and fixed by vojin154; technical notes in
`docs/direction-save.md`.
## Optional tweaks

These change game balance rather than fix bugs, so they are **off by default**.
Tick the ones you want in the patcher before clicking Apply (or pass
`--tweaks` on the command line to turn all of them on). Everything below is
marked "[Optional]" in the list. Technical notes for all three are in
`docs/tweaks.md`.

### No reoffending fine (Second Chances)

Every released prisoner who reoffends costs you a flat $5,000 "Prisoner
Reoffending Fine" two days after release, whether or not you had any say in
the release. This tweak removes the charge. Reoffending is still tracked,
reoffenders can still return, and the reward for prisoners who stay clean is
unchanged.

### No returning prisoners (Second Chances)

A reoffended prisoner can come back through intake as the exact prisoner who
left, with every reputation they earned inside, which is how an Extremely
Deadly, Extremely Volatile Min Sec turns up. With this tweak intake always
generates prisoners by the normal category rules. Reoffending statistics and
the fine are unaffected.

### Staff death morale penalty fades

Each staff member who dies on duty costs one point of staff morale for the
rest of the session. With this tweak the penalty fades by one death per
in-game day, and the "staff have died on duty" line in the staff morale panel
counts down with it. This tweak needs a little new code, so the patcher also
adds a small empty section to the executable; it is removed again when the
tweak is reverted.
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
  GUI. `TyrsPAPatch.exe` also accepts `--status`, `--apply` (add `--tweaks` for
  the optional tweaks) and `--revert`. It is a
  windowed program, so a console does not wait for it; scripts should use
  `Start-Process -Wait` or the PowerShell script above.
- `scripts/Build-*.ps1` regenerate each patch from the addresses in the
  script, and `tools/ghidra-scripts/` are the Ghidra scripts used to find them.
  Each fix has technical notes under `docs/`. Patches that need new code use a
  small section appended to the executable; see `docs/code-section.md`.
- Build the patcher with `dotnet build -c Release` in `patcher/`. It targets
  .NET Framework 4.8, which is already part of Windows 10 and 11.

## Credits

- **Paul Kinnair** (Weapon Firerate Fix) confirmed the reload-timer cause of the
  fire-rate bug and that the pre-Sunset build had no such timer.
- **Ozoneraxi** and **Deskius** (Alert Icons Partial Fix), with wackypanda and
  Quin_BNK: their offset formula pointed directly at the sprite-scale bug.
- **vojin154** (pa_fix_direction_serialization) found and fixed the lost
  directions first, and gave their blessing for the fix to be included here.
  Their DLL and this patch are compatible, but you only need one.
## Licence

MIT. See `LICENSE`.
