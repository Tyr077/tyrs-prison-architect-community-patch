# Ranged weapon fire rate

Patch: `patches/weapon-firerate.patch.json` (built by
`scripts/Build-Firerate.ps1`). Uses the code section (`code-section.md`).

## What you'll notice

Every gun waited two seconds after each shot, so assault rifles and SMGs fired
about once every two seconds and never automatically. With the fix, automatic
weapons fire automatically and other guns fire more often.

## What changes

After each shot a gun now waits:

| Weapon | Wait after each shot |
|---|---|
| Assault rifle, SMG, modified assault rifle (DLC) | 0.02 s |
| Tazer | 2 s (unchanged) |
| Every other gun | 0.7 s |

The weapon's `RechargeTime` from `materials.txt` is added on top, as before.

## Status

Shotgun rate tested in game (2026-09-22). Automatic weapons and Escape Mode not
yet tested.
