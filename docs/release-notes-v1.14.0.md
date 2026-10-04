Test build. Download the new `TyrsPAPatch.exe`, run it, click **Apply selection**. Your choices are kept.

## New in 1.14.0

- **Visits no longer stop because of one unusable visitor table.** With a second visitation room, or any visitor table or booth that no prisoner can be matched with (such as a booth facing an empty Protective Custody sector), visits could stop in the whole prison. The game now moves on to the next table, as the 2018 version did. Issue #4.

## Tested in game for this build

These were checked by running the game on test saves, with and without the patch:

- **Visitor tables** (new): on the save from issue #4, no visitor group formed in 50 tries without the fix; with it, 19 groups formed and 11 prisoners had visits.
- **Intake with route-restricted categories:** prisoners the route can't take are no longer refused and dropped; they stay queued for a route that accepts them.
- **Prisoners near gunfire surrender:** prisoners near the target react to guards' shots (none in 142 shots without the fix, 29 in 106 shots with it, at most ten per shot).
- **Shotgun fire rate:** armed guards' shotguns fire at the 2018 rate.
- **Disarmed armed guards can fight:** an armed guard without its weapon now fights with its fists.
- **Staff death morale penalty fades** (tweak): one death is forgiven per day.

## Also new since 1.5.0

- **Enhancements group.** Changes the game was missing rather than bug fixes. On by default like the fixes, and each can be unticked: shops without prisoners inside, disarmed armed guards can fight, hold to fire automatic weapons. `--fixes-only` on the command line leaves them out.
- **Prisoners near gunfire surrender.** A guard's gunshot makes up to ten prisoners within four squares react as if they were the target.
- **Fire rate revised.** Automatic weapons fire in a steady stream, while a revolver fires every 1.2 s and a shotgun every 1.7 s.
- **Muzzle flash, smoke and buckshot.** Assault rifles and SMGs show a muzzle flash and the shotgun fires a spread of buckshot with smoke again.
- **Armed guards reload in pavilions.** An armed guard manning a Guard Pavilion keeps firing instead of stopping after one shot.
- **Escape Mode Freefire with per-sector actions.** The warden's Freefire order after your gang kills someone now reaches the guards with "Search and Actions per sector" on.
- **Intake with route-restricted categories.** A helipad, boat dock or road that accepts only some prisoner categories no longer ends with *Your prison is closed to new inmates* while cells stand empty.
- **Visitor booths facing up.** Booths work with the prisoners' side at the top. Rotate the booth to face your prisoners while placing it.
- **Exercise equipment counts for grading.** Time on gym equipment counts towards the Health grade's exercise score.
- **Armed guard warnings is an optional tweak.** It was a fix in the 1.10.0 test build.
- **Patcher window rebuilt.** Items are grouped, your selections are remembered, and **Apply selection** also removes anything you untick.

## Also included

- Status effects set by a mod's Lua script work again.
- Staff go through keycard doors instead of taking long detours around them.
- Prisoner and staff directions are saved (first fixed by vojin154, included with their permission).
- Visitors and civilians no longer get stuck at single visitor doors.
- Released prisoners behind a revoked keycard door call a guard to let them out.
- Alert icons draw correctly with mods that bring their own sprite sheet. Disable the Alert Icons Partial Fix mod if you use it.
- Gang contraband hand-offs no longer leave prisoners and crooked guards stuck.

## Enhancements (on by default)

- **Shops without prisoners inside.** The shop front can face a hallway and prisoners buy from it without being allowed into the shop.
- **Disarmed armed guards can fight.** An armed guard who loses its shotgun fights with its fists while Freefire is on or it is badly hurt, instead of not fighting back. Its fists show while it has no weapon.
- **Hold to fire automatic weapons.** Holding the mouse button keeps assault rifles and SMGs firing in Warden Mode and Escape Mode, at zombies too.

## Optional tweaks (off by default)

- No reoffending fine (Second Chances)
- No returning prisoners (Second Chances)
- Staff death morale penalty fades by one death per day
- Armed guard warnings ignore overall staff morale
- Protective Custody prisoners work and attend programs in shared sectors

## Install

1. Download `TyrsPAPatch.exe` and close Prison Architect.
2. Run it, tick what you want, click **Apply selection**. SmartScreen warns once because the file is not code-signed: **More info**, then **Run anyway**.

If Steam verifies game files, run the patcher again. **Revert to original** undoes everything at any time. The patcher works on the final version of the game only; if you have the 2018 beta branch selected in Steam, switch back first.

## Please test

These need someone playing; they can't be checked automatically:

- **Visits:** if visits had stopped in your prison, do they start again?
- **Hold to fire:** in Warden Mode with an assault rifle or SMG, hold the left button on a target; it keeps firing. Also in Escape Mode with the assault rifle, SMG and modified assault rifle. Pistols and shotguns still need a click per shot.
- **Escape Mode Freefire:** in Escape Mode with "Search and Actions per sector" on, kill someone with your gang. Guards should switch to lethal force, and back after about three minutes.
- **Guard pavilion:** an armed guard stationed in a Guard Pavilion should keep firing during a riot or Freefire.
- **Weapon effects:** muzzle flash on assault rifles and SMGs, smoke and buckshot on shotguns.
- **Disarmed armed guards:** a guard that loses its shotgun should show its fists, and they should move when it punches.
- **Shops without prisoners inside:** a shop front facing a hallway, with the shop in a sector prisoners can't enter, should still sell.
- **Alert icons:** with a mod that brings its own sprite sheet, gang, CCTV and contraband icons draw correctly.

Each fix has a short page under `docs/`.

## Credits

- **Ozoneraxi** (AIO bug tracker and All-in-One mod) for the findings behind many of these fixes.
- **BurpBurp** and **Ozoneraxi** (Less Lethal Expansion), **Ozoneraxi** (AIO, fire rate), **vojin154** (pa_fix_direction_serialization), **Deskius**, wackypanda and Quin_BNK (Alert Icons Partial Fix), for the earlier fixes.

## Checksums (SHA-256)

- `TyrsPAPatch.exe`: `3e82c353dfd3a969a826cf0bee7afb456cf736821d55f6ffe57582224ed74706`
- Original `Prison Architect64.exe` this patch targets: `cc460fc435f2af4b1165f32cadde62b7943890ec8c9b2994e9f120830b2de1d9`
- `Prison Architect64.exe` with the sixteen fixes only: `4914c8a1ed2879bf175b47774f51cb5e9b557338935ce120edf4e5bb149b0f3c`
- `Prison Architect64.exe` with the fixes and the three enhancements (the default): `bc211628df633fb4d9d50b9ad51512ec1bf84770c5acae711cdd75fe1211d9b5`
- `Prison Architect64.exe` with everything, including all five tweaks: `dea217c33e364de0e36080c3039240097f48f6a7a9bbdec5c10e861c5a211ea3`
