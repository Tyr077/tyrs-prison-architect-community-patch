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
refuses to count the weapon's real recharge time until it expires. There is no
magazine or burst logic behind it; the two seconds are simply added to every
shot by everyone. Community Lua mods work around it by zeroing the timer every
tick on guards, which is expensive and cannot be applied to prisoners without
breaking Escape Mode.

Fix: the reload timer is set to a hair above zero instead of two seconds, so
it expires on the next tick and guards and prisoners fire at the
`RechargeTime` from `materials.txt`. The timer is kept rather than removed
because its expiry is also what ejects the shell casing and plays the shotgun
pump sound; the first version of this fix zeroed it and lost both. The Escape
Mode player attack, which relied on that timer as its only rate limit, is
given a proper rate limit based on the time since the last shot. Technical
notes, including the per-weapon values, in `docs/weapon-firerate.md`.

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

### Visitors and civilians stuck at visitor doors

Symptoms: reformed prisoners (Second Chances mentors), animal therapists, fire
safety teachers, delivery men and some other event-spawned NPCs stop at a
visitor door or visitor gate and never get through. Nobody comes to open it.
Double visitor doors work because a guard is sent.

Cause: the door's own "who may open me" list was never extended for the later
DLC entities, while the movement code already treats every non-prisoner as able
to open visitor doors, so it never asks a guard for help. The NPC is refused by
the door and waits forever.

Fix: the door now applies the same rule as the movement code: anyone who is
not a prisoner can open a visitor door. Prisoners are still refused. Technical
notes in `docs/visitor-door-access.md`.

### Staff detour around keycard doors

Symptoms: guards and other staff walk huge detours instead of going through a
keycard door, even with the key and the door right in front of them.

Cause: the route planner charges every keycard door a flat penalty of about a
thousand tiles of walking, the same penalty it uses for swimming across water,
and it charges it to staff with keys as well. Any other route, however long,
looks cheaper.

Fix: keycard doors are now costed like jail doors: key holders pass at normal
cost, everyone else needs a guard as before. Technical notes in
`docs/keycard-door-path-cost.md`.

### Released prisoners stuck behind revoked keycard doors

Symptoms: a keycard door with prisoner access revoked is the only way out of a
cell block. Prisoners whose sentence ends get the RELEASED nameplate and then
stand still forever; no guard is ever sent to let them out.

Cause: the route planner treats a revoked keycard door as a solid wall for
anyone without a staff key, instead of the usual "a guard has to open this"
that every other locked door gets. A released prisoner has no key, so there is
no route to the exit at all and they never start walking.

Fix: released prisoners (and prisoners under escort, who the game already lets
ignore deployment zones) now see a revoked keycard door as "needs a guard",
the same as a jail door, and a guard opens it for them. Prisoners still
serving time are refused as before, tracking belt or not. Technical notes in
`docs/keycard-door-released-prisoners.md`.

### Scripted status effects (mods)

Symptoms: mods that give prisoners a status effect from a Lua script
(`prisoner.StatusEffects.tazed = 60`, the feature added in Alpha 28 and used
by Less Lethal Expansion among others) do nothing. The script runs, reading
the value back shows it was set, but the prisoner is never tazed, sedated or
suppressed and the effect is not in the save file.

Cause: a later update made the game keep a separate list of which effects are
active on each prisoner. Everything that acts on effects, the per-tick decay,
the status icons, the AI checks and the save file, goes by that list. The
game's own code keeps it up to date; the Lua setter was never taught to, so a
scripted effect is written into a slot nobody looks at.

Fix: the Lua setter now activates the effect exactly as the game does, and
clears it again when set to 0, so scripted effects show up, wear off and
survive a save. This fix needs a little new code, so the patcher also adds a
small section to the executable; it is removed again on revert. Technical
notes in `docs/lua-status-effects.md`.

### Exercise on equipment not counted for grading

Symptoms: a prisoner's Health grade scores "% of stay exercising", but a prison
whose prisoners work out on gym equipment scores nothing for it however much
time they spend. Only prisoners jogging laps around a yard ever earn it.

Cause: the game credits that time from the prisoner's current *action*, and the
only activity tagged as the Exercise action is jogging in a yard. Weights
benches, treadmills, punch bags, gym mats and every other piece of equipment are
tagged "use an object", so their time is filed under free time instead, even
though the game is discharging the prisoner's Exercise need the whole while. A
poor Health grade also adds up to 25% to a prisoner's re-offending chance.

Fix: time on an object now counts as exercise whenever the thing being used is
one that serves the Exercise need, which is how the game already describes every
piece of equipment. DLC and modded equipment are covered without naming
anything, and the animations are untouched. Reported by Ozoneraxi, who
identified the cause; technical notes in `docs/exercise-grading.md`.

## Optional tweaks

These change game balance rather than fix bugs, so they are **off by default**.
Tick the ones you want in the patcher before clicking Apply selection (or pass
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
in-game day. The death count itself is left alone, so the "staff have died on
duty" line in the staff morale panel still shows the real number. This tweak
uses the same small code section as the scripted status effects fix.

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
  expected there, and the replacement bytes. The patcher embeds these. An edit
  may also carry `superseded`, the bytes earlier releases wrote at that site, so
  a game file patched by an older version is recognised and rewritten instead of
  being rejected as an unknown build.
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
- `docs/modding-framework-design.md` is a proposal (not yet built) for adding
  new Lua modding capabilities through the patcher, with stable and
  experimental tiers. First candidate: status effects on staff and other
  non-prisoner entities.

## Credits

- **Ozoneraxi** (All-in-One patch, AIO): fixed the ranged weapon fire rate a
  year before this patch did, as part of their all-in-one patching work. Their
  work on the reload timer established it as the cause of the bug and that the
  pre-Sunset build had no such timer; the 0.01 variant of that script is what
  showed the timer also drives the shell casings.
- **BurpBurp**, main contributor, and **Ozoneraxi** (Less Lethal Expansion):
  their mod is the reference use of the Alpha 28 `StatusEffects` scripting, and
  their scripts are what the scripted status effects fix was built and checked
  against.
- **Ozoneraxi** and **Deskius** (Alert Icons Partial Fix), with wackypanda and
  Quin_BNK: their offset formula pointed directly at the sprite-scale bug.
- **Ozoneraxi** (AIO bug tracker) worked out why exercise on equipment never
  counted towards the Health grade, down to the action tag responsible, and
  noted that no mod could fix it without losing the animations. That is exactly
  what this patch avoids by fixing the grading side instead.
- **vojin154** (pa_fix_direction_serialization) found and fixed the lost
  directions first, and gave their blessing for the fix to be included here.
  Their DLL and this patch are compatible, but you only need one.

## Licence

MIT. See `LICENSE`.
