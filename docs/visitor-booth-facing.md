# Visitor booths facing up

Patch: `patches/visitor-booth-facing.patch.json` (built by
`scripts/Build-VisitorBoothFacing.ps1`). Uses the code section
(`code-section.md`).

## What you'll notice

Visitor booths with the prisoners' side at the top never got any visits. With
the fix they work like booths with the prisoners' side at the bottom.

## What changes

When the game matched a waiting visitor with a prisoner at a booth facing up,
it checked the wrong side of the booth. It now checks the prisoners' side.

## Status

Tested in game with booths facing up. Other facings were not tested.

## Notes

The prisoners' side is the side the booth faces. The game draws the up and down
facings the same, so rotate the booth to face your prisoners while placing it.
