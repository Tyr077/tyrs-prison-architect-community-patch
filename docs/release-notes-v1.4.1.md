Changes one optional tweak and how the patcher handles files left by an older
release. No new bug fixes. Existing users: download the new `TyrsPAPatch.exe`,
run it, click **Apply patch**. Your tweak choices are kept.

## New in 1.4.1

**Staff death morale penalty fades: the death count is no longer altered.** The
tweak used to fade the penalty by lowering the game's own staff-death counter
once per in-game day, which also made the "staff have died on duty" line in the
staff morale panel count down. The line is meant to report history, so the tweak
now keeps its own tally of forgiven deaths and leaves the counter alone. The
morale penalty fades exactly as before, one death per in-game day, while the
panel keeps showing the real number. A tracing pass over every instruction that
reads the counter confirmed the panel and this formula are its only two readers.

**Upgrading no longer trips the unsupported-build check.** A game file patched
by an earlier release, where a patch has since changed its bytes, used to be
read as neither original nor patched, so the patcher declared the whole build
unknown and refused to touch it. Apply and Revert both stopped working, leaving
Steam's file verification as the only way out. Patch edits can now declare the
bytes older releases wrote, so such a file is recognised as outdated and
rewritten in place. Anyone who turned the morale tweak on in 1.2.0 through 1.4.0
would have hit this on upgrading to 1.4.1.

## Fixes included (unchanged)

- Gang contraband hand-off (Gangs DLC)
- Ranged weapon fire rate
- Alert icons with custom sprite-sheet mods
- Prisoner and staff directions not saved
- Staff detour around keycard doors
- Visitors and civilians stuck at visitor doors
- Released prisoners stuck behind revoked keycard doors

## Optional tweaks (off by default)

- No reoffending fine (Second Chances)
- No returning prisoners (Second Chances)
- Staff death morale penalty fades (changed, see above)

## Install

1. Download `TyrsPAPatch.exe`.
2. Close Prison Architect.
3. Run it, tick any optional tweaks you want, click **Apply patch**. Windows SmartScreen will warn once because the file is not code-signed: click **More info**, then **Run anyway**.

If Steam verifies game files it restores the original executable. Run the patcher again and click Apply. **Revert to original** undoes everything, tweaks included, at any time.

## Credits

- **Ozoneraxi** (All-in-One patch, AIO): worked around the ranged weapon fire rate for soldiers, Elite Ops and bounty hunters before this patch, as part of their all-in-one patching work, and their notes on the reload timer are what this fix was built and checked against.
- **vojin154** (pa_fix_direction_serialization), **Ozoneraxi** and **Deskius** (Alert Icons Partial Fix), with wackypanda and Quin_BNK, for the earlier fixes.

## Checksums (SHA-256)

- `TyrsPAPatch.exe`: `4a732edcdf00df23b461f6504384ca1ff5bfaf4479dc32f3a797ae0784d751ef`
- Original `Prison Architect64.exe` this patch targets: `cc460fc435f2af4b1165f32cadde62b7943890ec8c9b2994e9f120830b2de1d9`
- `Prison Architect64.exe` with the seven fixes applied: `836e77f484cdb5d263b1d7e11234d96d073ec2a542acc3f06b77c8ca669bd303`
- `Prison Architect64.exe` with the seven fixes and all three tweaks: `3cc97f70bcf79eb1713c976bbc5aaa49931bce1f2fe05be2278a3d4d97566fa3`
