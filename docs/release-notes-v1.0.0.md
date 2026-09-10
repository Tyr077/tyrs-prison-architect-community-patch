First public release. Three engine-level fixes for Prison Architect 1 (Steam Sunset Update build), delivered as a small patcher that edits your own game executable and can revert it.

## Fixes

**Gang contraband hand-off (Gangs DLC).** Prisoners no longer get stuck in the contraband hand-off state, pacing at speed while guards pick up and abandon search and return-to-cell jobs. Also fixes the crooked guard who stops working entirely, and hand-offs never happening again after you fire a crooked guard.

**Ranged weapon fire rate.** Every ranged weapon was capped at one shot per two seconds regardless of its `RechargeTime`, so assault rifles and SMGs never fired automatically. Guards and prisoners now fire at the rate set in `materials.txt`, including in Escape Mode, without any Lua workaround.

**Alert icons with custom sprite-sheet mods.** Notification icons that live in the `objects_d11_2` sheet (gang alerts, contraband, overheating, tropical fever, fallen trees, chewed fences, CCTV misconduct, tracking belts, plumbers and repairmen on site) drew from the wrong part of the sheet whenever a mod added its own `sprites.png`. The bakery oven glow had the same bug. All are fixed at the engine level. If you use the "Alert Icons Partial Fix" mod, disable it after applying this.

## Install

1. Download `TyrsPAPatch.exe`.
2. Close Prison Architect.
3. Run it, click **Apply patch**. Windows SmartScreen will warn once because the file is not code-signed: click **More info**, then **Run anyway**.

If Steam verifies game files it restores the original executable. Run the patcher again and click Apply. **Revert to original** undoes everything at any time. The patcher refuses any build other than the Steam Sunset Update and shows you the file hash so you can report it.

## Credits

- **Paul Kinnair** (Weapon Firerate Fix): confirmed the reload-timer cause of the fire-rate bug and that the pre-Sunset build had no such timer.
- **Ozoneraxi** and **Deskius** (Alert Icons Partial Fix), with wackypanda and Quin_BNK: their offset formula pointed directly at the sprite-scale bug.
- **vojin154** (pa_fix_direction_serialization): an independent, compatible fix that showed what binary patching of this game can do.

## Checksums (SHA-256)

- `TyrsPAPatch.exe`: `229f9c3b2be0bfeb55d5bf97df09edf7a91191f990d5b1acc6031514710be31f`
- Original `Prison Architect64.exe` this patch targets: `cc460fc435f2af4b1165f32cadde62b7943890ec8c9b2994e9f120830b2de1d9`
