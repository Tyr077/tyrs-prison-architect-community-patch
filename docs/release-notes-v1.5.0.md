Adds one bug fix for modders. Existing users: download the new `TyrsPAPatch.exe`,
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

## Fixes included

- Gang contraband hand-off (Gangs DLC)
- Ranged weapon fire rate
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

- **Ozoneraxi** (Less Lethal Expansion) and the modders who reported that the Alpha 28 `StatusEffects` scripting had stopped working.
- **vojin154** (pa_fix_direction_serialization), **Paul Kinnair** (Weapon Firerate Fix), **Ozoneraxi** and **Deskius** (Alert Icons Partial Fix), with wackypanda and Quin_BNK, for the earlier fixes.

## Checksums (SHA-256)

- `TyrsPAPatch.exe`: (recorded at release)
- Original `Prison Architect64.exe` this patch targets: `cc460fc435f2af4b1165f32cadde62b7943890ec8c9b2994e9f120830b2de1d9`
- `Prison Architect64.exe` with the eight fixes applied: `3d94d5edcf2e6e1c767016b1a09c82ba5241cd5b85bb77c74b81ab80d6ef8cb0`
- `Prison Architect64.exe` with the eight fixes and all three tweaks: `66eb297f6cb3a590c8e2b1a74938d55180efc0a671ffcdb607031d8a79113cb4`
