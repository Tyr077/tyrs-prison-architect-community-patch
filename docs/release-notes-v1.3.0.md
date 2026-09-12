Adds two bug fixes, both about doors. Existing users: download the new `TyrsPAPatch.exe`, run it, click **Apply patch**. Your tweak choices are kept.

## New in 1.3.0

**Staff detour around keycard doors.** Guards and other staff walked huge detours instead of going through a keycard door, even holding the key with the door right in front of them. The route planner charged every keycard door a flat penalty of about a thousand tiles of walking, the same it uses for swimming across water, and charged it to key holders too, so any other route looked cheaper. Keycard doors are now costed like jail doors: key holders pass at normal cost, everyone else needs a guard as before. Technical notes in `docs/keycard-door-path-cost.md`.

**Visitors and civilians stuck at visitor doors.** Reformed prisoners (Second Chances mentors), animal therapists, fire safety teachers, delivery men and some other event-spawned NPCs would stop at a visitor door or visitor gate and never get through, and no guard was sent to open it. The door's own "who may open me" list was never extended for the later DLC entities, while the movement code already assumed every non-prisoner could open visitor doors and so never asked for a guard. The door now uses the same rule: anyone who is not a prisoner can open a visitor door. Prisoners are still refused. Technical notes in `docs/visitor-door-access.md`.

## Fixes included

- Gang contraband hand-off (Gangs DLC)
- Ranged weapon fire rate
- Alert icons with custom sprite-sheet mods
- Prisoner and staff directions not saved
- Staff detour around keycard doors (new)
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
- **Ozoneraxi** (All-in-One patch, AIO): fixed the ranged weapon fire rate a year before this patch did, as part of their all-in-one patching work.
- **vojin154** (pa_fix_direction_serialization), **Paul Kinnair** (Weapon Firerate Fix), **Ozoneraxi** and **Deskius** (Alert Icons Partial Fix), with wackypanda and Quin_BNK, for the earlier fixes.

## Checksums (SHA-256)

- `TyrsPAPatch.exe`: `71c87468a28bf1c38ae9b9e238edbea4f9b042ee18ccf57db3337943bd88a310`
- Original `Prison Architect64.exe` this patch targets: `cc460fc435f2af4b1165f32cadde62b7943890ec8c9b2994e9f120830b2de1d9`
- `Prison Architect64.exe` with the six fixes applied: `55ba0d45dbb53c930a6324b04ef0b7f21f9111ac14f4afe2b7b26875e63e09f4`
- `Prison Architect64.exe` with the six fixes and all three tweaks: `b7473193e36196ba82a4cb4efd908d4e30babc406fe18a62ca307ca8d72f0037`
