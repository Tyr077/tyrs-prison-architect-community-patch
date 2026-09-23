Test build. Download the new `TyrsPAPatch.exe`, run it, click **Apply selection**. Your tweak choices are kept.

This build was made after comparing the game with its 2018 version (the Steam beta branch), so that "what the game used to do" comes from the old code and not from memory.

## New in 1.11.0

- **Prisoners near gunfire surrender.** A guard's gunshot makes up to ten prisoners within four squares react as if they were the target, and most of them surrender. The 2018 version did this; the final version had lost the code.
- **Fire rate now matches the 2018 version.** Automatic weapons fire as fast as before. Pistols, shotguns and rifles wait 0.7 s between shots again (the Tazer 2 s), on top of their recharge time: a revolver fires every 1.2 s, a shotgun every 1.7 s. Earlier versions of this fix removed the wait altogether, which was faster than the game ever was.
- **Armed guard warnings is now an optional tweak.** The 2018 version scales an armed guard's warning chance with overall staff morale in exactly the same way, so that is how the game was designed, not a bug. If you had it from the 1.10.0 test build it shows as installed under **Optional tweaks**; untick it to get the game's own behaviour back.

## Also new since 1.5.0

- **Muzzle flash, smoke and buckshot.** Assault rifles and SMGs show a muzzle flash and the shotgun fires a spread of buckshot with smoke again. Automatic rifles also stop playing a full burst sound for every round.
- **Armed guards reload in pavilions.** An armed guard manning a Guard Pavilion keeps firing instead of stopping after one shot.
- **Disarmed armed guards can fight.** An armed guard who loses its shotgun fights with its fists instead of getting stuck while Freefire is on or it is badly hurt.
- **Escape Mode Freefire with per-sector actions.** The warden's Freefire order after your gang kills someone now reaches the guards with "Search and Actions per sector" on.
- **Hold to fire automatic weapons.** Holding the mouse button keeps assault rifles and SMGs firing in Warden Mode and Escape Mode, at zombies too.
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

## Optional tweaks (off by default)

- No reoffending fine (Second Chances)
- No returning prisoners (Second Chances)
- Staff death morale penalty fades by one death per day
- Armed guard warnings ignore overall staff morale

## Install

1. Download `TyrsPAPatch.exe` and close Prison Architect.
2. Run it, tick what you want, click **Apply selection**. SmartScreen warns once because the file is not code-signed: **More info**, then **Run anyway**.

If Steam verifies game files, run the patcher again. **Revert to original** undoes everything at any time. The patcher works on the final version of the game only; if you have the 2018 beta branch selected in Steam, switch back first.

## Please test

- **Gunfire surrender:** a riot or a brawl near armed guards, Freefire on. When a guard shoots, prisoners standing near the target or the guard should drop to the ground with their hands up, not only the one who was shot. A few tough ones may go for the guard instead.
- **Fire rate:** armed guards with shotguns should fire about every two seconds, snipers about every three, and assault rifles and SMGs in a steady stream. In Escape Mode a pistol fires a little more often than once a second.
- The 1.9.0 and 1.10.0 fixes as listed in those test build notes.

How each fix works, in plain English, is in `docs/fixes-explained.md`.

## Credits

- **Ozoneraxi** (AIO bug tracker and All-in-One mod) for the findings behind the weapon-effects, pavilion, disarmed-guard, Escape Mode Freefire and full-auto fixes, for recording that armed guards had stopped causing surrenders around them, and for the intake, booth, shop and exercise findings.
- **BurpBurp** and **Ozoneraxi** (Less Lethal Expansion), **Ozoneraxi** (AIO, fire rate), **vojin154** (pa_fix_direction_serialization), **Deskius**, wackypanda and Quin_BNK (Alert Icons Partial Fix), for the earlier fixes.

## Checksums (SHA-256)

- `TyrsPAPatch.exe`: `ef7baafe03b0eac6ffa3b707c3985e0c15843d540a5e8d74f54c30ff38ce7ace`
- Original `Prison Architect64.exe` this patch targets: `cc460fc435f2af4b1165f32cadde62b7943890ec8c9b2994e9f120830b2de1d9`
- `Prison Architect64.exe` with the eighteen fixes applied: `1fafca9e2f8eb63328574d0655672e4255b88bd17205f949c979e537829dd0f4`
- `Prison Architect64.exe` with the eighteen fixes and all four tweaks: `a457ee4e757c9773803983cc8ba19df3e0a0da0f9f204db5243404105105243f`
