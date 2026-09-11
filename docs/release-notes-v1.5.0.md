Adds one bug fix for modders and corrects the fire-rate fix. Existing users: download the new `TyrsPAPatch.exe`,
run it, click **Apply patch**. Your tweak choices are kept.

## New in 1.5.0

**Scripted status effects work again.** Alpha 28 let a mod's Lua script give a
prisoner a status effect directly (`prisoner.StatusEffects.tazed = 60`), and mods
such as Less Lethal Expansion rely on it for tazer shotguns, sedative rounds and
stun rods. A later update made the game track which effects are active in a
separate flag set that the per-tick decay, the status icons, the AI checks and
the save file all consult, and the Lua setter was never updated to touch it. The
value was written into a slot nobody read, so scripted effects did nothing while
reading them back from Lua still showed the number. The setter now activates the
effect the way the game's own code does, and clears it again when set to 0.

This fix needs a little new code, so the patcher now always adds the small extra
section to the executable that was previously only used by the morale tweak. It
is removed again on revert. Technical notes in `docs/lua-status-effects.md`; a
small test mod is in `tools/testmods/lua-status-effects-test/`.

**Fire-rate fix keeps shell casings and the shotgun pump sound.** The fix that
restores `RechargeTime` as the rate of fire used to switch the per-shot reload
timer off completely. It was reported that guards had stopped ejecting shell
casings: the timer's expiry is also what spawns the casing and plays the
shotgun pump sound. The timer is now set to a hair above zero instead, so it
expires on the next tick and both come back, right after the shot instead of
two seconds later. Rates are unchanged: revolver 0.5 s, shotgun 1 s, sniper
rifle 2 s, assault rifle and SMG 0.1 s, as in `materials.txt`. The game has no
magazine or burst logic for guards; `Ammo` only applies to the player's gang in
Escape Mode. The notes in `docs/weapon-firerate.md` now list every weapon's
values and the shipped-versus-fixed cadence.

## Fixes included

- Gang contraband hand-off (Gangs DLC)
- Ranged weapon fire rate (changed, see above)
- Alert icons with custom sprite-sheet mods
- Prisoner and staff directions not saved
- Staff detour around keycard doors
- Visitors and civilians stuck at visitor doors
- Released prisoners stuck behind revoked keycard doors
- Scripted status effects (new)

## Optional tweaks (off by default)

- No reoffending fine (Second Chances)
- No returning prisoners (Second Chances)
- Staff death morale penalty fades

## Install

1. Download `TyrsPAPatch.exe`.
2. Close Prison Architect.
3. Run it, tick any optional tweaks you want, click **Apply patch**. Windows SmartScreen will warn once because the file is not code-signed: click **More info**, then **Run anyway**.

If Steam verifies game files it restores the original executable. Run the patcher again and click Apply. **Revert to original** undoes everything, tweaks included, at any time.

## Credits

- **Ozoneraxi** (Less Lethal Expansion): their mod is the reference use of the Alpha 28 `StatusEffects` scripting, and their scripts and notes on it are what the fix was built and checked against.
- **Paul Kinnair** (Weapon Firerate Fix): their Lua work on the reload timer, and the 0.01 variant of it that keeps the casings, showed exactly which part of the timer mattered.
- **vojin154** (pa_fix_direction_serialization), **Ozoneraxi** and **Deskius** (Alert Icons Partial Fix), with wackypanda and Quin_BNK, for the earlier fixes.

## Checksums (SHA-256)

- `TyrsPAPatch.exe`: `e0b08873ecf9cd51efc3c4ffe155aba2273a5e0f43e0542244bff30b379ce9d0`
- Original `Prison Architect64.exe` this patch targets: `cc460fc435f2af4b1165f32cadde62b7943890ec8c9b2994e9f120830b2de1d9`
- `Prison Architect64.exe` with the eight fixes applied: `18d53efe09301f0d9f37c2cdb77008d138365f2157a2dd43c0ddc9856510823f`
- `Prison Architect64.exe` with the eight fixes and all three tweaks: `90fa1c9b3578497547200430737d14a17c0382c086e8d93a9b22c00ea6210aa6`
