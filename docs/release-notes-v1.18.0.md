Test build. Download the new `TyrsPAPatch.exe`, run it, click **Apply selection**. Your choices are kept.

## New in 1.18.0

- **Assigned guards blocking solitary and treatment.** A prisoner with a guard assigned to them (**Assign Guard** on the rap sheet, or the Chief's Guard Assignment) was never taken to solitary and never treated in their cell unless you did it by hand. They are now punished and treated like everyone else, and the guard goes back to watching afterwards.
- **Weapon effects for mod weapons (modding extension, experimental).** A gun a mod adds can now ask for a muzzle flash, smoke, buckshot, a burst sound or automatic fire with the `materials.txt` key `Tyrs.WeaponEffects`, and gets them from the patch's weapon fixes like the vanilla guns. Mod authors: see `docs/weapon-effects-key.md`. Vanilla weapons behave as before.
- **Status effects on staff: crash fixed (modding extension).** Giving a staff member or other non-prisoner `virusdeadly` or `calamityflu` crashed the game, and so did loading a save with such a character. Both effects are now refused on non-prisoners, and those saves load again.

Muzzle flash, smoke and buckshot, the fire rate fix and hold to fire get a small update for the weapon key: the patcher shows them as an older version until you click **Apply selection**.

## Tested in game for this build

- **Assigned guards:** five prisoners with an assigned guard and a pending solitary punishment, next to five without one. Without the fix none of the five with a guard went to solitary in about 20 game hours; with it all ten did.
- **Weapon effects for mod weapons:** with the example weapons from the mod-author page, carried by armed guards in a riot: the automatic rifle fired automatically with a muzzle flash on every shot, the shotgun fired buckshot with smoke, and a mod gun without the key, or a redefined SMG asking for `None`, got neither. Without the extension the key is ignored and vanilla guns keep their effects.
- **Status effects on staff:** all 27 effects on six kinds of character, no crash; the two refused ones read back as 0, and the unpatched game loads the save.
- A game patched with 1.5.0, 1.15.0, 1.16.2 or 1.17.0 upgrades to the same file as a fresh install, and every combination reverts to the original.

Checked in earlier test builds: visitors wasted on prisoners with no family, fix detection for mods, visitors in every visitation room, modding extension detection and the docs' example scripts, bounty hunter trike rider (sprite-sheet fix), status effects on staff, disarmed armed guards show the game's fists, shop front (on a player's save), intake with route-restricted categories, prisoners near gunfire surrender, fire rate (shotgun, automatic weapons, Escape Mode), staff death morale penalty fades (tweak).

## Also new since 1.5.0

- **Visitors wasted on prisoners with no family.** Visitors are no longer matched with prisoners who have no family and can never be visited, so they are not used up for nothing.
- **Mods can check which fixes are installed.** Besides the modding extensions, a mod can ask whether a bug fix or tweak is installed, for example to leave out its own workaround. Mod authors: see `docs/modding-api.md`.
- **Visitors in every visitation room.** With several visitation rooms, the room the game checked first could take nearly all visitors while the others got few or none. Each new visitor now starts looking one visitor table further along, so every room gets its turn, and one visitor table that no prisoner can be matched with no longer stops visits in the whole prison. Issue #4.
- **One box for modding extensions.** The patcher shows **Modding extensions** as a single box that turns all of them on or off, instead of a list. Still off by default.
- **Guide for mod authors.** `docs/modding-api.md` lists the extensions and shows how a mod checks for one and how to tell players what to tick. Each extension has its own page with a full example script.
- **More sprite-sheet pictures fixed.** With a mod that brings its own sprite sheet, the rider on the bounty hunters' trike (Undead DLC) and object pictures in panels such as the staff report drew the wrong part of the sheet, like the alert icons did. The alert icons fix now covers them too. Disable the Alert Icons Partial Fix mod if you use it.
- **Modding extensions (experimental, off by default).** New things for mod authors to use from Lua; they do nothing unless a mod uses them. **Status effects on staff and other characters** gives every character the `StatusEffects` table that only prisoners had, so a mod can taze or sedate a guard. The extra code needs a larger code section in the game file (8 KiB instead of 4 KiB) for everyone; a game patched by an older release is upgraded in place.
- **Core fixes and additional fixes.** The patcher's groups are now **Core fixes** (bugs in the game's code) and **Additional fixes** (things the game never finished, or that players expect it to do). Disarmed armed guards can fight and hold to fire automatic weapons are core fixes now, so `--fixes-only` on the command line includes them. Additional fixes is empty for now, so the patcher doesn't show it.
- **Disarmed armed guards can fight.** An armed guard who loses its shotgun fights with its fists while Freefire is on or it is badly hurt, instead of not fighting back, and shows the game's own fists.
- **Hold to fire automatic weapons.** Holding the mouse button keeps assault rifles and SMGs firing in Warden Mode and Escape Mode, at zombies too.
- **Shops without prisoners inside.** Prisoners buy from the other side of the shop front, so the shop can face a hallway and stay off limits to customers.
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

## Please test

These need someone playing; they can't be checked automatically:

- **Assigned guards:** a prisoner with an assigned guard who gets hurt in their cell should be treated by a doctor, and searches should still happen.
- **Mod weapons:** with a `FullAuto` mod gun, holding the left button keeps it firing in Warden Mode and Escape Mode.
- **Sprite-sheet pictures:** with a mod that brings its own sprite sheet, the staff report and the security menu's prisoner pictures draw correctly, for bounty hunters too.
- **Visits:** with several visitation rooms, does every room get visitors? If visits had stopped in your prison, do they start again?
- **Hold to fire:** in Warden Mode with an assault rifle or SMG, hold the left button on a target; it keeps firing. Also in Escape Mode with the assault rifle, SMG and modified assault rifle. Pistols and shotguns still need a click per shot.
- **Escape Mode Freefire:** in Escape Mode with "Search and Actions per sector" on, kill someone with your gang. Guards should switch to lethal force, and back after about three minutes.
- **Guard pavilion:** an armed guard stationed in a Guard Pavilion should keep firing during a riot or Freefire.
- **Weapon effects:** muzzle flash on assault rifles and SMGs, smoke and buckshot on shotguns.
- **Mod authors:** try the weapon key on your own guns and the status effects extension on staff, using the guide in `docs/modding-api.md`.

Each fix has a short page under `docs/`; mod authors start at `docs/modding-api.md`.

## Credits

- **Ozoneraxi** (AIO bug tracker and All-in-One mod) for the findings behind many of these fixes. The Alert Icons Partial Fix's list of icons is how the trike rider was found.
- **BurpBurp** and **Ozoneraxi** (Less Lethal Expansion), **Ozoneraxi** (AIO, fire rate), **vojin154** (pa_fix_direction_serialization), **Deskius**, wackypanda and Quin_BNK (Alert Icons Partial Fix), for the earlier fixes.

## Checksums (SHA-256)

- `TyrsPAPatch.exe`: `5b037479258cbb42664afb17d4d385ab507cb0673d9ee2c9ffa62cffc95f21ba`
- Original `Prison Architect64.exe` this patch targets: `cc460fc435f2af4b1165f32cadde62b7943890ec8c9b2994e9f120830b2de1d9`
- `Prison Architect64.exe` with the twenty-one core fixes (the default, and `--fixes-only`): `ac365248f435d7777f77a3903c5026095e3745c583e150a93d11844d56dbfa22`
- `Prison Architect64.exe` with the core fixes and all five tweaks: `782478c556e44b66eeaaa5d3e41efa66ed9879fe4217b2977604275ec6098dba`
- `Prison Architect64.exe` with everything, including the tweaks and the two experimental modding extensions: `5168a3d635def7f32247044e88d33892b42b6526c58290938bcf59eef40db3fc`
