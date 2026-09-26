# Prisoner and staff directions saved

Patch: `patches/direction-save.patch.json`.

## What you'll notice

Direction markings placed for prisoners or staff were gone after loading a
save. With the fix they are still there.

## What changes

The game now writes the direction markings into the save file instead of
leaving their values out.

## Status

Tested in game.

## Notes

vojin154 fixed this first with a DLL mod; this fix is included with their
permission. Their DLL is compatible with the patch, but you only need one.
