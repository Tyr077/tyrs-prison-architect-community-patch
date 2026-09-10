Adds a fifth bug fix. Existing users: download the new `TyrsPAPatch.exe`, run it, click **Apply patch**. Your tweak choices are kept.

## New in 1.3.0

**Visitors and civilians stuck at visitor doors.** Reformed prisoners (Second Chances mentors), animal therapists, fire safety teachers, delivery men and some other event-spawned NPCs would stop at a visitor door or visitor gate and never get through, and no guard was sent to open it. The door's own "who may open me" list was never extended for the later DLC entities, while the movement code already assumed every non-prisoner could open visitor doors and so never asked for a guard. The door now uses the same rule: anyone who is not a prisoner can open a visitor door. Prisoners are still refused. Technical notes in `docs/visitor-door-access.md`.

## Fixes included

- Gang contraband hand-off (Gangs DLC)
- Ranged weapon fire rate
- Alert icons with custom sprite-sheet mods
- Prisoner and staff directions not saved
- Visitors and civilians stuck at visitor doors (new)

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

- The players on the community Discord who reported the visitor-door behaviour, narrowed it down to specific NPC types and door types, and shared their save-side workaround.
- **vojin154** (pa_fix_direction_serialization), **Paul Kinnair** (Weapon Firerate Fix), **Ozoneraxi** and **Deskius** (Alert Icons Partial Fix), with wackypanda and Quin_BNK, for the earlier fixes.

## Checksums (SHA-256)

- `TyrsPAPatch.exe`: `91605bb23a95b93bfeda013e93ade07d631c2a87941ff79a37b75b8525a125a0`
- Original `Prison Architect64.exe` this patch targets: `cc460fc435f2af4b1165f32cadde62b7943890ec8c9b2994e9f120830b2de1d9`
- `Prison Architect64.exe` with the five fixes applied: `944d0eefc9fc4f5316a5370e5e01097e6ba1cd81005ff3175046f0933166325b`
- `Prison Architect64.exe` with the five fixes and all three tweaks: `3612ca729b8d3a5497e18ae7550b493a84970f3d472b8a5ee303e3d44441807f`
