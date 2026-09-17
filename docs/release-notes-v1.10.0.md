Test build. Download the new `TyrsPAPatch.exe`, run it, click **Apply selection**. Your tweak choices are kept.

## New in 1.10.0

- **Armed guards warn again with Staff Needs on.** An armed guard's chance to shout a warning before firing no longer scales with the prison's overall staff morale. A guard whose own needs are neglected still fires without warning.
- **Hold to fire at zombies.** Holding the button in Warden Mode now keeps firing at zombies too, not only in attack mode (1.9.0 test build report).

## Also new since 1.5.0

- **Muzzle flash, smoke and buckshot.** Assault rifles and SMGs show a muzzle flash and the shotgun fires a spread of buckshot with smoke again. Automatic rifles also stop playing a full burst sound for every round.
- **Armed guards reload in pavilions.** An armed guard manning a Guard Pavilion keeps firing instead of stopping after one shot.
- **Disarmed armed guards can fight.** An armed guard who loses its shotgun fights with its fists instead of getting stuck while Freefire is on or it is badly hurt.
- **Escape Mode Freefire with per-sector actions.** The warden's Freefire order after your gang kills someone now reaches the guards with "Search and Actions per sector" on.
- **Hold to fire automatic weapons.** Holding the mouse button keeps assault rifles and SMGs firing in Warden Mode and Escape Mode.
- **Intake with route-restricted categories.** A helipad, boat dock or road that accepts only some prisoner categories no longer ends with *Your prison is closed to new inmates* while cells stand empty.
- **Visitor booths facing up.** Booths work with the prisoners' side at the top. Rotate the booth to face your prisoners while placing it. Confirmed in a test prison on 16 September.
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

- **Armed guard warnings:** Staff Needs on, staff morale low. An armed guard confronting a misbehaving prisoner should shout a warning about as often as with Staff Needs off. Guards with neglected needs may still fire straight away; that is the game's own rule and unchanged.
- **Hold to fire at zombies:** in Warden Mode with an assault rifle or SMG, hold the button over zombies. It should keep firing.
- The other 1.9.0 fixes as listed in the 1.9.0 test build notes.

How each fix works, in plain English, is in `docs/fixes-explained.md`.

## Credits

- **Ozoneraxi** (AIO bug tracker and All-in-One mod) for the findings behind the weapon-effects, pavilion, disarmed-guard, Escape Mode Freefire and full-auto fixes, and for the intake, booth, shop and exercise findings.
- **BurpBurp** and **Ozoneraxi** (Less Lethal Expansion), **Ozoneraxi** (AIO, fire rate), **vojin154** (pa_fix_direction_serialization), **Deskius**, wackypanda and Quin_BNK (Alert Icons Partial Fix), for the earlier fixes.

## Checksums (SHA-256)

- `TyrsPAPatch.exe`: (filled in after the build)
- Original `Prison Architect64.exe` this patch targets: `cc460fc435f2af4b1165f32cadde62b7943890ec8c9b2994e9f120830b2de1d9`
- `Prison Architect64.exe` with the eighteen fixes applied: `3d169eab7d0bce277f6f363e561140634b886c3548629fc111522a5da276fe70`
- `Prison Architect64.exe` with the eighteen fixes and all three tweaks: `deaf1694b445148c402d33f1434152212648b54c80fc9c9ea94bc77645f7cad4`
