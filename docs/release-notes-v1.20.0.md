Test build. Everything in the 1.19.0 stable release, plus one new modding extension. Download the new `TyrsPAPatch.exe`, run it, click **Apply selection**. Your choices are kept.

## New in 1.20.0

- **Hand colours for characters (modding extension, experimental).** A `materials.txt` block, `HandColours`, sets the hand colour of any character type, per sprite variant. Until now every character a mod adds had the same light hands whatever its sprite looked like, and redrawn staff kept the hand colours of the vanilla sprites. Mod authors: see `docs/hand-colours.md`, which also lists the game's default hand colours ready to copy. Tick **Modding extensions** in the patcher to use it.

Nothing else changes: with **Modding extensions** off, your game file is the same as with 1.19.0.

## Tested in game for this build

- **Hand colours:** in a riot, with blocks for guards, armed guards, janitors and prisoners: every guard variant got its own colour, armed guards got their variant 0 colour and the `All` colour for the rest, a line that isn't a colour was skipped but kept its place, prisoners got their colour also with their hands up, and blocks naming an unknown object or no object were reported in `debug.txt`. Without the extension the blocks are ignored.
- A game patched with 1.5.0, 1.16.2, 1.17.0, 1.18.0 or 1.19.0 upgrades to the same file as a fresh install, and every combination reverts to the original.

## Please test

- **Mod authors:** try `HandColours` on your own characters and redrawn staff, and tell us what you'd change while it's experimental.
- Hands with an alpha below `FF`, and prisoners' heads with a `Prisoner` block, haven't been looked at yet.

## Install

1. Download `TyrsPAPatch.exe` and close Prison Architect.
2. Run it, tick what you want, click **Apply selection**. SmartScreen warns once because the file is not code-signed: **More info**, then **Run anyway**.

If Steam verifies game files, run the patcher again. **Revert to original** undoes everything at any time. The patcher works on the final version of the game only; if you have the 2018 beta branch selected in Steam, switch back first.

## Credits

- **Ozoneraxi** (AIO bug tracker and All-in-One mod) for the findings behind many of the fixes.
- **BurpBurp** and **Ozoneraxi** (Less Lethal Expansion), **Ozoneraxi** (AIO, fire rate), **vojin154** (pa_fix_direction_serialization), **Deskius**, wackypanda and Quin_BNK (Alert Icons Partial Fix), for the earlier fixes.

## Checksums (SHA-256)

- `TyrsPAPatch.exe`: `PATCHER_SHA`
- Original `Prison Architect64.exe` this patch targets: `cc460fc435f2af4b1165f32cadde62b7943890ec8c9b2994e9f120830b2de1d9`
- `Prison Architect64.exe` with the twenty-three core fixes (the default, and `--fixes-only`): `SHA_DEFAULT`
- `Prison Architect64.exe` with the core fixes and all five tweaks: `SHA_TWEAKS`
- `Prison Architect64.exe` with everything, including the tweaks and the three experimental modding extensions: `SHA_ALL`
