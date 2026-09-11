Adds one bug fix. Existing users: download the new `TyrsPAPatch.exe`, run it, click **Apply patch**. Your tweak choices are kept.

## New in 1.4.0

**Released prisoners stuck behind revoked keycard doors.** When a keycard door with prisoner access revoked was the only way out of a cell block, prisoners whose sentence ended got the RELEASED nameplate and then stood still forever; no guard was ever sent to let them out. The route planner treated a revoked keycard door as a solid wall for anyone without a staff key, instead of the usual "a guard has to open this" that every other locked door gets, so a released prisoner had no route to the exit at all. Released prisoners (and prisoners under escort, who the game already lets ignore deployment zones) now see a revoked keycard door as "needs a guard", the same as a jail door, and a guard opens it for them. Prisoners still serving time are refused as before, tracking belt or not. Confirmed on the reporter's save. Technical notes in `docs/keycard-door-released-prisoners.md`.

## Fixes included

- Gang contraband hand-off (Gangs DLC)
- Ranged weapon fire rate
- Alert icons with custom sprite-sheet mods
- Prisoner and staff directions not saved
- Staff detour around keycard doors
- Visitors and civilians stuck at visitor doors
- Released prisoners stuck behind revoked keycard doors (new)

## Optional tweaks (unchanged, off by default)

- No reoffending fine (Second Chances)
- No returning prisoners (Second Chances)
- Staff death morale penalty fades

## Install

1. Download `TyrsPAPatch.exe`.
2. Close Prison Architect.
3. Run it, tick any optional tweaks you want, click **Apply patch**. Windows SmartScreen will warn once because the file is not code-signed: click **More info**, then **Run anyway**.

If Steam verifies game files it restores the original executable. Run the patcher again and click Apply. **Revert to original** undoes everything, tweaks included, at any time.

## Credits

- The player on the community Discord who reported the released-prisoner behaviour and shared the test save that reproduces it.
- **vojin154** (pa_fix_direction_serialization), **Paul Kinnair** (Weapon Firerate Fix), **Ozoneraxi** and **Deskius** (Alert Icons Partial Fix), with wackypanda and Quin_BNK, for the earlier fixes.

## Checksums (SHA-256)

- `TyrsPAPatch.exe`: see the release page; recorded in the follow-up commit.
- Original `Prison Architect64.exe` this patch targets: `cc460fc435f2af4b1165f32cadde62b7943890ec8c9b2994e9f120830b2de1d9`
- `Prison Architect64.exe` with the seven fixes applied: `836e77f484cdb5d263b1d7e11234d96d073ec2a542acc3f06b77c8ca669bd303`
- `Prison Architect64.exe` with the seven fixes and all three tweaks: `d5fbb38573214524e00e267091ff04ffdcced3f11df785916559a97f68e31a3d`
