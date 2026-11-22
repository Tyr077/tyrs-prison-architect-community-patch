Stable release, the first since 1.5.0. It has every fix from the test builds since then. Existing users: download the new `TyrsPAPatch.exe`, run it, click **Apply selection**. Your choices are kept.

## New fixes since 1.5.0

- **Reform programs without equipment restart every session.** Flower Therapy and Three Strikes took all their students off before every session and put them back on, which started their progress over. Students now stay on and their progress builds up, so these programs pass prisoners like the others. Issue #5.
- **Patrolling guards counted as available.** The top bar's available guards no longer include guards and armed guards on patrol, who only take jobs where they happen to walk. They still show under Patrolling in the tooltip. Issue #7.
- **Assigned guards blocking solitary and treatment.** A prisoner with a guard assigned to them is taken to solitary and treated like everyone else again.
- **Visitors in every visitation room.** With several visitation rooms, every room now gets its turn, and one visitor table that no prisoner can be matched with no longer stops visits in the whole prison. Issue #4.
- **Visitors wasted on prisoners with no family.** Visitors are no longer matched with prisoners who can never be visited.
- **Shops without prisoners inside.** Prisoners buy from the other side of the shop front, so the shop can face a hallway and stay off limits to customers.
- **Intake with route-restricted categories.** A helipad, boat dock or road that accepts only some prisoner categories no longer ends with *Your prison is closed to new inmates* while cells stand empty.
- **Visitor booths facing up.** Booths work with the prisoners' side at the top. Rotate the booth to face your prisoners while placing it.
- **Exercise equipment counts for grading.** Time on gym equipment counts towards the Health grade's exercise score.
- **Prisoners near gunfire surrender.** A shot by an armed guard, soldier or sniper makes up to ten prisoners within four squares react as if they were the target. Bounty hunters' shots don't count, so prisoners no longer turn on them (a problem in the 1.11 to 1.18 test builds).
- **Armed guards reload in pavilions.** An armed guard manning a Guard Pavilion keeps firing instead of stopping after one shot.
- **Disarmed armed guards can fight.** An armed guard who loses its shotgun fights with its fists while Freefire is on or it is badly hurt, and shows the game's own fists.
- **Muzzle flash, smoke and buckshot.** Assault rifles and SMGs show a muzzle flash and the shotgun fires a spread of buckshot with smoke again.
- **Fire rate revised.** Automatic weapons fire in a steady stream, while a revolver fires every 1.2 s and a shotgun every 1.7 s.
- **Hold to fire automatic weapons.** Holding the mouse button keeps assault rifles and SMGs firing in Warden Mode and Escape Mode.
- **Escape Mode Freefire with per-sector actions.** The warden's Freefire order after your gang kills someone now reaches the guards with "Search and Actions per sector" on.
- **More sprite-sheet pictures fixed.** With a mod that brings its own sprite sheet, the bounty hunters' trike rider (Undead DLC) and object pictures in panels such as the staff report now draw correctly, like the alert icons. Disable the Alert Icons Partial Fix mod if you use it.

## Patcher and modding

- **Patcher window rebuilt.** Fixes and tweaks are grouped, your selections are remembered, and **Apply selection** also removes anything you untick.
- **Modding extensions (experimental, off by default).** New things for mod authors to use from Lua, behind one **Modding extensions** box. They do nothing unless a mod uses them: status effects on staff and other characters, and weapon effects for mod weapons (the `materials.txt` key `Tyrs.WeaponEffects`).
- **Mods can check which fixes are installed**, for example to leave out their own workaround.
- Mod authors: start at `docs/modding-api.md`.

## Also included

- Status effects set by a mod's Lua script work again.
- Staff go through keycard doors instead of taking long detours around them.
- Prisoner and staff directions are saved (first fixed by vojin154, included with their permission).
- Visitors and civilians no longer get stuck at single visitor doors.
- Released prisoners behind a revoked keycard door call a guard to let them out.
- Gang contraband hand-offs no longer leave prisoners and crooked guards stuck.

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

## Not yet confirmed in game

Every fix has been tested in game, but these parts of them haven't been seen yet. Reports welcome:

- Flower Therapy (Three Strikes is tested).
- Armed guards on patrol left out of the guard count.
- Doctors treating a prisoner who has an assigned guard (solitary is tested).
- Whether more prisoners end up surrendering during a riot (that they react is tested).
- Visitor booths facing other ways than up.
- Hold to fire with the modified assault rifle, and at zombies.
- The sprite-sheet fix's panel pictures (staff report, security menu) on screen; the trike rider is tested.
- Holding the button with a `FullAuto` mod weapon (modding extension).

Each fix has a short page under `docs/`.

## Credits

- **Ozoneraxi** (AIO bug tracker and All-in-One mod) for the findings behind many of these fixes. The Alert Icons Partial Fix's list of icons is how the trike rider was found.
- **BurpBurp** and **Ozoneraxi** (Less Lethal Expansion), **Ozoneraxi** (AIO, fire rate), **vojin154** (pa_fix_direction_serialization), **Deskius**, wackypanda and Quin_BNK (Alert Icons Partial Fix), for the earlier fixes.

## Checksums (SHA-256)

- `TyrsPAPatch.exe`: `47b73f0a7e740e8450aee69967504a2950b771422fad5adec52757ad486e4491`
- Original `Prison Architect64.exe` this patch targets: `cc460fc435f2af4b1165f32cadde62b7943890ec8c9b2994e9f120830b2de1d9`
- `Prison Architect64.exe` with the twenty-three core fixes (the default, and `--fixes-only`): `6e2602536b91c29687485e23705fb69b0d05b22602d567f3cfec008cc69345b6`
- `Prison Architect64.exe` with the core fixes and all five tweaks: `13e43cf22d47f8e8d90d4e39626e8430b744b6f0e330a024e3b33483b46988b9`
- `Prison Architect64.exe` with everything, including the tweaks and the two experimental modding extensions: `134ef9cae86d8baf73de05fa8a60c738866162a188fdccc1373f51d244a5d3a7`
