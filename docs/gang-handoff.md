# Gang contraband hand-off (Gangs DLC)

Patch: `patches/gang-handoff.patch.json` (built by `scripts/Build-Patch.ps1`).

## What you'll notice

A contraband hand-off could leave a gang member pacing forever or a crooked
guard doing nothing. With the fix, a hand-off that cannot go ahead is called
off and both go back to normal.

## What changes

- If the crooked guard is fired or dies, a new one is picked and the waiting
  gang member is released.
- If the gang member is gone, the guard drops the hand-off and goes back to its
  normal duties.
- If the regime changes so the hand-off can no longer happen, the gang member
  stops waiting instead of pacing until the next free time.

## Notes

Existing saves need no editing. A gang member already stuck is released on its
next update.

## Status

Tested in game.
