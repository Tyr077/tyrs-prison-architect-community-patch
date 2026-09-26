Test build. Download the new `TyrsPAPatch.exe`, run it, click **Apply selection**. Your tweak choices are kept.

## New since 1.5.0

- **Intake with route-restricted categories.** A helipad, boat dock or road that accepts only some prisoner categories no longer ends with *Your prison is closed to new inmates* while cells stand empty. Every category you take still needs at least one route that accepts it.
- **Visitor booths facing up.** Booths now work with the prisoners' side at the top, not just the bottom. The game draws both facings the same, so rotate the booth to face your prisoners while placing it.
- **Shops without prisoners inside.** The shop front can face a hallway and prisoners buy from it without being allowed into the shop, so who works in a shop and who shops there can be kept apart.
- **Exercise equipment counts for grading.** Time on gym equipment now counts towards the Health grade's exercise score, not just jogging laps around the yard.
- **Patcher window rebuilt.** Fixes and tweaks are grouped, your selections are remembered, and **Apply selection** also removes anything you untick.

## Also included

- Mods that set status effects from Lua, such as Less Lethal Expansion, work again: tazed, sedated and suppressed prisoners actually are.
- Staff go through keycard doors instead of taking long detours around them.
- Prisoner and staff directions are saved (first fixed by vojin154, included with their permission).
- Visitors and civilians no longer get stuck at single visitor doors.
- Released prisoners whose only way out is a keycard door with belt access revoked now call a guard to let them out.
- Alert icons draw correctly with mods that bring their own sprite sheet. Disable the Alert Icons Partial Fix mod if you use it.
- Gang contraband hand-offs no longer leave prisoners and crooked guards stuck.
- Assault rifles and SMGs fire at their real rate instead of once every two seconds.

## Optional tweaks (off by default)

- No reoffending fine (Second Chances)
- No returning prisoners (Second Chances)
- Staff death morale penalty fades by one death per day

## Install

1. Download `TyrsPAPatch.exe` and close Prison Architect.
2. Run it, tick what you want, click **Apply selection**. SmartScreen warns once because the file is not code-signed: **More info**, then **Run anyway**.

If Steam verifies game files, run the patcher again. **Revert to original** undoes everything at any time.

## Please test

Intake and booths are verified in the code but not yet in a running prison. Report what you find in an issue; if your antivirus objects to the patched game file, say so too.

- **Intake:** one route for some categories (a helipad for Max Sec), another for the rest, Fill Capacity, a few days at speed. Both kinds should keep arriving.
- **Booths:** prisoners' sector above the booths, booths rotated to face up. Visits should take place. Other facings and visitor tables should be unchanged.

Each fix has a short page under `docs/`.

## Credits

- **Ozoneraxi** (AIO bug tracker) for the findings behind the intake, booth, shop and exercise fixes.
- **BurpBurp** and **Ozoneraxi** (Less Lethal Expansion), **Ozoneraxi** (AIO, fire rate), **vojin154** (pa_fix_direction_serialization), **Deskius**, wackypanda and Quin_BNK (Alert Icons Partial Fix), for the earlier fixes.

## Checksums (SHA-256)

- `TyrsPAPatch.exe`: `c6c3e3bb899e6dd006bb8e593dc4606c0754ce577d2e7385478847bc13aa00d2`
- Original `Prison Architect64.exe` this patch targets: `cc460fc435f2af4b1165f32cadde62b7943890ec8c9b2994e9f120830b2de1d9`
- `Prison Architect64.exe` with the twelve fixes applied: `abc00ad59876212f79a879af269879fdae5982ed8e1e5f1bd3296cf7f891e300`
- `Prison Architect64.exe` with the twelve fixes and all three tweaks: `99c12563ad0c79c5d5791a56a32cc80801892458543750f2df6f252205647630`
