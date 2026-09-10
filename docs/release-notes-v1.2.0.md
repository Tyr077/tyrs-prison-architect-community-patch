Adds optional balance tweaks. They are **off by default**: the four bug fixes still apply with one click, and nothing changes for you unless you tick a tweak. Existing users: download the new `TyrsPAPatch.exe`, run it, tick what you want, click **Apply patch**.

## New in 1.2.0: optional tweaks

Each one is marked "[Optional]" in the list and unticked until you choose it. On the command line, `--apply --tweaks` turns all of them on.

**No reoffending fine (Second Chances).** Removes the flat $5,000 "Prisoner Reoffending Fine" charged two days after any released prisoner reoffends. Reoffending is still tracked, reoffenders can still return, and the reward for prisoners who stay clean is unchanged.

**No returning prisoners (Second Chances).** Reoffended prisoners no longer come back through intake as the exact prisoner who left, reputations and all. Intake always generates prisoners by the normal category rules. Statistics and the fine are unaffected.

**Staff death morale penalty fades.** The one-point-per-death staff morale penalty now fades by one death per in-game day, and the "staff have died on duty" line in the staff morale panel counts down with it. This tweak needs a little new code, so the patcher also adds a small empty section to the game executable when it is on, and removes it when it is reverted.

## Fixes included (unchanged)

- Gang contraband hand-off (Gangs DLC)
- Ranged weapon fire rate
- Alert icons with custom sprite-sheet mods
- Prisoner and staff directions not saved

## Install

1. Download `TyrsPAPatch.exe`.
2. Close Prison Architect.
3. Run it, tick any optional tweaks you want, click **Apply patch**. Windows SmartScreen will warn once because the file is not code-signed: click **More info**, then **Run anyway**.

If Steam verifies game files it restores the original executable. Run the patcher again and click Apply. **Revert to original** undoes everything, tweaks included, at any time.

## Credits

- **vojin154** (pa_fix_direction_serialization): found and fixed the lost-directions bug first, and blessed its inclusion.
- **Paul Kinnair** (Weapon Firerate Fix): confirmed the reload-timer cause of the fire-rate bug and that the pre-Sunset build had no such timer.
- **Ozoneraxi** and **Deskius** (Alert Icons Partial Fix), with wackypanda and Quin_BNK: their offset formula pointed directly at the sprite-scale bug.
- The players on the community Discord who described the Second Chances and staff morale behaviour that these tweaks address.

## Checksums (SHA-256)

- `TyrsPAPatch.exe`: `09fa3bbcfb263f0090189acd1484416986742d3bbc7003fb12c2364cf31f323e`
- Original `Prison Architect64.exe` this patch targets: `cc460fc435f2af4b1165f32cadde62b7943890ec8c9b2994e9f120830b2de1d9`
- `Prison Architect64.exe` with the four fixes applied: `fbee9dc8654ee4612b6742d41d6acf550231960e1c416dc848c1e950bb924a72`
- `Prison Architect64.exe` with the four fixes and all three tweaks: `a9a9388ef5c4f1e6458873de3de8d2a07761c72133a4e311ba636f46c36b8fda`
