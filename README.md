# Tyr's Prison Architect Community Patch

Fixes for bugs in Prison Architect 1's own code, delivered as a small
patcher that edits your own copy of the game.

This project does not contain or distribute the game. The patcher only edits the
`Prison Architect64.exe` you already own, keeps a backup, and can put everything
back.

Works with the Steam "Sunset Update" build, which is the final version of the
game. Other builds (GOG, Epic, older versions) are detected and refused; see
"Unsupported build" below.

## Download

Two kinds of release, the way mod sites do it:

- **Stable** — the normal release, marked *Latest*.
  This is the one to take unless you have a reason not to.
- **Test build** — a pre-release, tagged `-testN`. Has the newest fixes in it,
  but not all of them have been confirmed in-game yet. Take one of these if you want to
  help test, or if it fixes something that is bothering you now.

Both are a single `TyrsPAPatch.exe` on the
[Releases page](https://github.com/Tyr077/tyrs-prison-architect-community-patch/releases);
there is nothing to build. Either way your game file is backed up before
anything is written, and **Revert to original** puts it back at any time.

The fixes listed below are what is in the newest test build. The stable release
may be behind them; each release says what is in it.

## Install

1. Download `TyrsPAPatch.exe` from the latest release.
2. Close Prison Architect.
3. Run `TyrsPAPatch.exe`. It finds the game in your Steam library, shows which
   fixes are installed, and has an **Apply selection** button. That is it.

Windows SmartScreen will warn the first time because the file is not
code-signed. Click **More info**, then **Run anyway**. Each release lists the
SHA256 of the download so you can check it.

If Steam ever runs "Verify integrity of game files", it restores the original
executable. Just run the patcher again and click Apply.

The patcher groups everything into **Bug fixes** and **Optional tweaks**. Both
groups are ticked or unticked as a whole, or expanded to pick individual items,
and each line says whether it is currently installed in your game. Your choices
are remembered for next time, and **Apply selection** makes the game match them:
it installs what you ticked and removes what you unticked.

**Revert to original** restores the unpatched game at any time, whatever is
ticked.

## Fixes included

Each entry links to a short page on the fix and whether it has been tested in
game.

- **Prisoners near gunfire surrender.** A guard's gunshot makes up to ten
  prisoners within four squares react as if they were the target.
  [Details](docs/gunfire-surrender.md)
- **Muzzle flash, smoke and buckshot.** Assault rifles and SMGs show a muzzle
  flash and the shotgun fires a spread of buckshot with smoke again.
  [Details](docs/weapon-effects.md)
- **Armed guards reload in pavilions.** An armed guard manning a Guard Pavilion
  keeps firing instead of stopping after one shot.
  [Details](docs/pavilion-reload.md)
- **Disarmed armed guards can fight.** An armed guard who loses its shotgun
  fights with its fists while Freefire is on or it is badly hurt, instead of not
  fighting back. [Details](docs/disarmed-armed-guards.md)
- **Escape Mode Freefire with per-sector actions.** The warden's Freefire order
  after your gang kills someone now reaches the guards when "Search and Actions
  per sector" is on. [Details](docs/escape-freefire-sectors.md)
- **Hold to fire automatic weapons.** Holding the mouse button keeps assault
  rifles and SMGs firing in Warden Mode and Escape Mode, at zombies too.
  [Details](docs/full-auto-hold.md)
- **Intake with route-restricted categories.** A helipad, boat dock or road that
  accepts only some prisoner categories no longer ends with *Your prison is
  closed to new inmates* while cells stand empty. Every category you take still
  needs at least one route that accepts it.
  [Details](docs/intake-route-categories.md)
- **Visitor booths facing up.** Booths work with the prisoners' side at the top,
  not just the bottom. Rotate the booth to face your prisoners while placing
  it.
  [Details](docs/visitor-booth-facing.md)
- **Shops without prisoners inside.** The shop front can face a hallway and
  prisoners buy from it without being allowed into the shop, so who works in a
  shop and who shops there can be kept apart.
  [Details](docs/shop-front.md)
- **Exercise equipment counts for grading.** Time on gym equipment counts towards
  the Health grade's exercise score, not just jogging laps around the yard.
  [Details](docs/exercise-grading.md)
- **Scripted status effects (mods).** Mods that set status effects from Lua, such
  as Less Lethal Expansion, work again: tazed, sedated and suppressed prisoners
  actually are. Adds a small code section to the executable, removed on revert.
  [Details](docs/lua-status-effects.md)
- **Staff detour around keycard doors.** Staff go through keycard doors instead
  of taking long detours around them.
  [Details](docs/keycard-door-path-cost.md)
- **Prisoner and staff directions saved.** Direction markings survive a save and
  load. First fixed by vojin154, included with their permission.
  [Details](docs/direction-save.md)
- **Visitors and civilians stuck at visitor doors.** Mentors, therapists
  and other visitors no longer wait forever at a single visitor
  door or gate. [Details](docs/visitor-door-access.md)
- **Released prisoners behind revoked keycard doors.** When a keycard door with
  prisoner access revoked is the only way out, released prisoners call a guard to
  let them out instead of standing still forever.
  [Details](docs/keycard-door-released-prisoners.md)
- **Alert icons with custom sprite-sheet mods.** Alert icons and the bakery oven
  glow draw correctly with mods that bring their own `sprites.png`. Disable the
  Alert Icons Partial Fix mod if you use it. [Details](docs/alert-icons.md)
- **Gang contraband hand-off (Gangs DLC).** Hand-offs no longer leave gang
  members pacing forever or crooked guards doing nothing.
  [Details](docs/gang-handoff.md)
- **Ranged weapon fire rate.** Assault rifles and SMGs fire automatically
  instead of once every two seconds, and other guns wait 0.7 s between shots
  instead of two seconds, plus the weapon's `RechargeTime` from `materials.txt`.
  [Details](docs/weapon-firerate.md)

## Optional tweaks

Balance changes rather than bug fixes, so they are **off by default**. Tick them
in the patcher, or pass `--tweaks` on the command line to turn all of them on.
[Details](docs/tweaks.md)

- **No reoffending fine (Second Chances).** Removes the flat $5,000 charge when a
  released prisoner reoffends.
- **No returning prisoners (Second Chances).** Intake always generates new
  prisoners instead of bringing back reoffenders with all their old reputations.
- **Staff death morale penalty fades.** The morale penalty for staff deaths
  shrinks by one death per in-game day; the death count itself is unchanged.
- **Armed guard warnings ignore overall staff morale.** With Staff Needs on, an
  armed guard's chance to shout a warning before attacking no longer scales with
  the prison's overall staff morale. A guard whose own needs are neglected still
  attacks without warning. Listed as a fix in the 1.10.0 test build.
- **Protective Custody prisoners work and attend programs in shared sectors.**
  Protective Custody prisoners take jobs and go to classes in Shared sectors and
  in Custom sectors that include Protective Custody, not only in Protective
  Custody Only sectors.

## Unsupported build

The patcher checks the game file before touching anything. If it says
"Unsupported game build", it will not change your game. Click **Copy file
hash** and open an issue with the hash and where you bought the game. If enough
people have that build it can be supported.

## Reporting other bugs

Fixes are considered for reproducible bugs in the game's code. Please include a save file that shows the bug, what you expected to happen, and
what happens instead.

## For the technically inclined

- `patches/*.patch.json` are the actual patches: file offsets, the bytes
  expected there, and the replacement bytes. The patcher embeds these. An edit
  may also carry `superseded`, the bytes earlier releases wrote at that site, so
  a game file patched by an older version is recognised and rewritten instead of
  being rejected as an unknown build.
- `scripts/Apply-ExePatch.ps1` applies a patch file from PowerShell without the
  GUI. `TyrsPAPatch.exe` also accepts `--status`, `--apply` (add `--tweaks` for
  the optional tweaks) and `--revert`. It is a
  windowed program, so a console does not wait for it; scripts should use
  `Start-Process -Wait` or the PowerShell script above.
- `scripts/Build-*.ps1` regenerate each patch. Patches that need new code use a
  small section appended to the executable; see `docs/code-section.md`.
- Build the patcher with `dotnet build -c Release` in `patcher/`. It targets
  .NET Framework 4.8, which is already part of Windows 10 and 11.

## Credits

- **Ozoneraxi** (All-in-One patch and its bug tracker): the findings behind the
  fire rate, pavilion, shop, exercise, intake, visitor booth and several weapon
  fixes.
- **BurpBurp** and **Ozoneraxi** (Less Lethal Expansion): the scripts the
  scripted status effects fix was built and checked against.
- **Ozoneraxi** and **Deskius** (Alert Icons Partial Fix), with wackypanda and
  Quin_BNK: their work pointed at the alert icon bug.
- **vojin154** (pa_fix_direction_serialization) fixed the lost directions
  first and gave their blessing for the fix to be included here. Their DLL and
  this patch are compatible, but you only need one.

## Licence

MIT. See `LICENSE`.
