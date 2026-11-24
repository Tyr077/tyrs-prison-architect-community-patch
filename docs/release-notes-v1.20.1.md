Test build. Everything in 1.20.0 test build 1, with two changes. Download the new `TyrsPAPatch.exe`, run it, click **Apply selection**. Your choices are kept, and a game patched with an older version is brought up to date.

## New in 1.20.1

- **Available guards: more staff left out.** The top bar's available count no longer includes dog handlers on patrol, snipers in a guard tower or bamboo tower, or guards, armed guards, dog handlers and snipers in the warden's squad in Warden Mode. Orderlies on patrol still count: they take jobs outside their patrol, so they are free for work. Issue #7.
- **Hand colours: the mod highest in the list wins (modding extension, experimental).** When several mods have a `HandColours` block for the same character, the first one the game reads wins as a whole, as with the game's own definitions, and the others are skipped with a line in `debug.txt`. Before, a mod lower in the list overrode it variant by variant.

## Tested in game for this build

- **Available guards:** dog handlers on patrol, snipers in towers, armed guards on patrol and three guards added to the warden's squad were left out of the count; without the fix every count matched the game's own rule. Patrolling orderlies took jobs outside the area they were patrolling.
- **Hand colours:** with a second mod below the first naming guards and armed guards again, every guard and armed guard had the first mod's colours, and `debug.txt` listed the two skipped blocks.
- A game patched with 1.5.0, 1.18.0, 1.19.0 or 1.20.0 upgrades to the same file as a fresh install, and every combination reverts to the original.

## Please test

- **Mod authors:** `HandColours` with your mods in different list orders.
- The Reduce Staff Stress grant's "available guards" goal with the new count.

## Install

1. Download `TyrsPAPatch.exe` and close Prison Architect.
2. Run it, tick what you want, click **Apply selection**. SmartScreen warns once because the file is not code-signed: **More info**, then **Run anyway**.

If Steam verifies game files, run the patcher again. **Revert to original** undoes everything at any time. The patcher works on the final version of the game only; if you have the 2018 beta branch selected in Steam, switch back first.

## Credits

- **Ozoneraxi** (AIO bug tracker and All-in-One mod) for the findings behind many of the fixes.
- **BurpBurp** and **Ozoneraxi** (Less Lethal Expansion), **Ozoneraxi** (AIO, fire rate), **vojin154** (pa_fix_direction_serialization), **Deskius**, wackypanda and Quin_BNK (Alert Icons Partial Fix), for the earlier fixes.

## Checksums (SHA-256)

- `TyrsPAPatch.exe`: `567645eff77ec522cf9848e9a8df1cecdf280e81d157b6b6f31f6a3d6f4a862c`
- Original `Prison Architect64.exe` this patch targets: `cc460fc435f2af4b1165f32cadde62b7943890ec8c9b2994e9f120830b2de1d9`
- `Prison Architect64.exe` with the twenty-three core fixes (the default, and `--fixes-only`): `ebdba2bf0c3516303eb79cf567ef688732910778df912b6f30ea9de02dee14db`
- `Prison Architect64.exe` with the core fixes and all five tweaks: `fd470d1ef9252e3ed5b954a3a82e042ab68d762bf878a29dd3a992346a86ffaf`
- `Prison Architect64.exe` with everything, including the tweaks and the three experimental modding extensions: `4fc8036d33cf29a3e9b85724e679f791e69587c7104133aa14e2da4de3e2bee5`
