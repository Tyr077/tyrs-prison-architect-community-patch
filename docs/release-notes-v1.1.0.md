Adds a fourth fix. Existing users: download the new `TyrsPAPatch.exe`, run it, and click **Apply patch**. It applies only what is missing and leaves the fixes you already have in place.

## New in 1.1.0

**Prisoner and staff directions not saved.** Direction markings placed for prisoners or staff were lost every time a save was loaded. The save writer could not write single-byte fields, so the value was dropped. The game now writes those fields as plain numbers. First fixed by **vojin154** (pa_fix_direction_serialization), who kindly agreed to its inclusion. Their DLL and this patch are compatible, but you only need one.

## Fixes included

- Gang contraband hand-off (Gangs DLC)
- Ranged weapon fire rate
- Alert icons with custom sprite-sheet mods
- Prisoner and staff directions not saved (new)

## Install

1. Download `TyrsPAPatch.exe`.
2. Close Prison Architect.
3. Run it, click **Apply patch**. Windows SmartScreen will warn once because the file is not code-signed: click **More info**, then **Run anyway**.

If Steam verifies game files it restores the original executable. Run the patcher again and click Apply. **Revert to original** undoes everything at any time. The patcher refuses any build other than the Steam Sunset Update and shows you the file hash so you can report it.

## Credits

- **vojin154** (pa_fix_direction_serialization): found and fixed the lost-directions bug first, and blessed its inclusion.
- **Ozoneraxi** (All-in-One patch, AIO): worked around the ranged weapon fire rate for soldiers, Elite Ops and bounty hunters before this patch, as part of their all-in-one patching work, and their notes on the reload timer are what this fix was built and checked against.
- **Ozoneraxi** and **Deskius** (Alert Icons Partial Fix), with wackypanda and Quin_BNK: their offset formula pointed directly at the sprite-scale bug.

## Checksums (SHA-256)

- `TyrsPAPatch.exe`: `8319d819a8e9384d96a9c0aa6c6a15e321afdb492ba76f8632976417885e9794`
- Original `Prison Architect64.exe` this patch targets: `cc460fc435f2af4b1165f32cadde62b7943890ec8c9b2994e9f120830b2de1d9`
- `Prison Architect64.exe` with all four fixes applied: `fbee9dc8654ee4612b6742d41d6acf550231960e1c416dc848c1e950bb924a72`
