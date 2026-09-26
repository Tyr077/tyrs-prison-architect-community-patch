Adds one bug fix for modders and corrects the fire-rate fix. Existing users: download the new `TyrsPAPatch.exe`,
run it, click **Apply patch**. Your tweak choices are kept.

## New in 1.5.0

- **Scripted status effects work again.** Status effects that a mod's Lua script gives a prisoner, such as being tazed, take effect again.
- **Fire-rate fix keeps shell casings and the shotgun pump sound.** Guards eject shell casings and the shotgun pump sound plays again after each shot; fire rates are unchanged.

## Fixes included

- Gang contraband hand-off (Gangs DLC)
- Ranged weapon fire rate (changed, see above)
- Alert icons with custom sprite-sheet mods
- Prisoner and staff directions not saved
- Staff detour around keycard doors
- Visitors and civilians stuck at visitor doors
- Released prisoners stuck behind revoked keycard doors
- Scripted status effects (new)

## Optional tweaks (off by default)

- No reoffending fine (Second Chances)
- No returning prisoners (Second Chances)
- Staff death morale penalty fades

## Install

1. Download `TyrsPAPatch.exe`.
2. Close Prison Architect.
3. Run it, tick any optional tweaks you want, click **Apply patch**. Windows SmartScreen will warn once because the file is not code-signed: click **More info**, then **Run anyway**.

If Steam verifies game files it restores the original executable. Run the patcher again and click Apply. **Revert to original** undoes everything, tweaks included, at any time.

## Credits

- **BurpBurp**, main contributor, and **Ozoneraxi** (Less Lethal Expansion): their mod is the reference use of the Alpha 28 `StatusEffects` scripting, and their scripts and notes on it are what the fix was built and checked against.
- **Ozoneraxi** (All-in-One patch, AIO): worked around the ranged weapon fire rate for soldiers, Elite Ops and bounty hunters before this patch, as part of their all-in-one patching work, and their notes on the reload timer, including the 0.01 variant that keeps the casings, are what this fix was built and checked against.
- **vojin154** (pa_fix_direction_serialization), **Ozoneraxi** and **Deskius** (Alert Icons Partial Fix), with wackypanda and Quin_BNK, for the earlier fixes.

## Checksums (SHA-256)

- `TyrsPAPatch.exe`: `e0b08873ecf9cd51efc3c4ffe155aba2273a5e0f43e0542244bff30b379ce9d0`
- Original `Prison Architect64.exe` this patch targets: `cc460fc435f2af4b1165f32cadde62b7943890ec8c9b2994e9f120830b2de1d9`
- `Prison Architect64.exe` with the eight fixes applied: `18d53efe09301f0d9f37c2cdb77008d138365f2157a2dd43c0ddc9856510823f`
- `Prison Architect64.exe` with the eight fixes and all three tweaks: `90fa1c9b3578497547200430737d14a17c0382c086e8d93a9b22c00ea6210aa6`
