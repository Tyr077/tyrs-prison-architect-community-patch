# Patrolling guards counted as available

Patch: `patches/available-guards-patrol.patch.json`.

## What you'll notice

The top bar's guard count, and the "Available" line in its tooltip, included
guards and armed guards on patrol. A patrolling guard only takes jobs where it
happens to be walking, and a patrolling armed guard takes none, so the number
looked like you had spare guards when you didn't. With the fix, patrolling guards
are left out of "Available", as they were before the final update. They still
show under "Patrolling" in the tooltip.

## What changes

Only the number. Guards do the same jobs as before. The Reduce Staff Stress
grant's "available guards" goal counts the same way, so patrolling guards no
longer count towards it either.

Snipers, and guards on strike, are still counted.

## Status

Tested in game for guards: without the fix the count included idle patrolling
guards (up to 10 at once); with it they were left out in 62 of 63 checks. Armed
guards on patrol and the grant goal are not tested.
