# Patrolling guards counted as available

Patch: `patches/available-guards-patrol.patch.json`.

## What you'll notice

The top bar's guard count, and the "Available" line in its tooltip, included
staff who weren't free for other work. With the fix, these are left out:

- guards, armed guards and dog handlers on patrol (a patrolling guard only takes
  jobs where it happens to be walking; patrolling armed guards and dog handlers
  take none)
- snipers in a guard tower
- guards, armed guards, dog handlers and snipers in the warden's squad in
  Warden Mode

They still show under their own lines in the tooltip, such as "Patrolling".

## What changes

Only the number. Staff do the same jobs as before. The Reduce Staff Stress
grant's "available guards" goal counts the same way.

Not changed: orderlies on patrol still count as available. In testing they
took jobs outside the area they were patrolling, so they are free for work.
Guards on strike also still count.

## Status

Tested in game (1.1.0): with the fix the counters left out patrolling guards
and dog handlers, snipers in towers, patrolling armed guards and three guards
added to the warden's squad, and matched in at least 60 of 62 checks per
type. Without it, every counter matched the game's own rule in every check.
The grant goal is not tested.
