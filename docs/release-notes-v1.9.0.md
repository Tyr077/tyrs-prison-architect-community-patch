Test build. Download the new `TyrsPAPatch.exe`, run it, click **Apply selection**. Your tweak choices are kept.

## New in 1.9.0

- **Muzzle flash, smoke and buckshot.** Assault rifles and SMGs show a muzzle flash and the shotgun fires a spread of buckshot with smoke again. Automatic rifles also stop playing a full burst sound for every round.
- **Armed guards reload in pavilions.** An armed guard manning a Guard Pavilion keeps firing instead of stopping after one shot.
- **Disarmed armed guards can fight.** An armed guard who loses its shotgun fights with its fists while Freefire is on or it is badly hurt, instead of with an empty hand that does no damage.
- **Escape Mode Freefire with per-sector actions.** The warden's Freefire order after your gang kills someone now reaches the guards with "Search and Actions per sector" on.
- **Hold to fire automatic weapons.** Holding the mouse button keeps assault rifles and SMGs firing in Warden Mode and Escape Mode.

## Also new since 1.5.0

- **Intake with route-restricted categories.** A helipad, boat dock or road that accepts only some prisoner categories no longer ends with *Your prison is closed to new inmates* while cells stand empty.
- **Visitor booths facing up.** Booths work with the prisoners' side at the top. Rotate the booth to face your prisoners while placing it.
- **Shops without prisoners inside.** The shop front can face a hallway and prisoners buy from it without being allowed into the shop.
- **Exercise equipment counts for grading.** Time on gym equipment counts towards the Health grade's exercise score.
- **Patcher window rebuilt.** Fixes and tweaks are grouped, your selections are remembered, and **Apply selection** also removes anything you untick.

## Also included

- Mods that set status effects from Lua, such as Less Lethal Expansion, work again.
- Staff go through keycard doors instead of taking long detours around them.
- Prisoner and staff directions are saved (first fixed by vojin154, included with their permission).
- Visitors and civilians no longer get stuck at single visitor doors.
- Released prisoners behind a revoked keycard door call a guard to let them out.
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

The five new fixes, intake and booths are verified in the code but not yet in a running game. Report what you find in an issue.

- **Effects:** watch an armed guard with a shotgun and one with an assault rifle fire. The shotgun should throw smoke and a spread of pellets, the rifle a muzzle flash, and the rifle's burst sound should no longer stack up.
- **Pavilions:** an armed guard manning a Guard Pavilion during a fight should keep shooting.
- **Disarmed armed guards:** Freefire on, let prisoners take an armed guard's shotgun. The guard should keep fighting with its fists.
- **Escape Mode:** with per-sector actions on, kill a guard or prisoner with your gang. Guards should switch to lethal force for three minutes.
- **Hold to fire:** in Warden Mode and Escape Mode, hold the button with an assault rifle or SMG. It should keep firing; a revolver or shotgun should still fire once per click.
- **Intake** and **booths:** as in the 1.8.0 test build.

Each fix has a short page under `docs/`.

## Credits

- **Ozoneraxi** (AIO bug tracker and All-in-One mod) for the findings behind the weapon-effects, pavilion, disarmed-guard, Escape Mode Freefire fixes, and the pavilion workaround script that confirmed the reload cause; and for the intake, booth, shop and exercise findings.
- **BurpBurp** and **Ozoneraxi** (Less Lethal Expansion), **Ozoneraxi** (AIO, fire rate), **vojin154** (pa_fix_direction_serialization), **Deskius**, wackypanda and Quin_BNK (Alert Icons Partial Fix), for the earlier fixes.

## Checksums (SHA-256)

- `TyrsPAPatch.exe`: `a2142e699ba7cd5d9f075f401447432c682e26b710ca8cda3d44db9a936f0aca`
- Original `Prison Architect64.exe` this patch targets: `cc460fc435f2af4b1165f32cadde62b7943890ec8c9b2994e9f120830b2de1d9`
- `Prison Architect64.exe` with the seventeen fixes applied: `337000bbf6df779f18f942519713c628298602276d4442341cc6f8bcd06a34bd`
- `Prison Architect64.exe` with the seventeen fixes and all three tweaks: `071ac1adcb32b3cacef8dd3c6fbab5ff283b092772357abcdae0496ce4e7cbac`
