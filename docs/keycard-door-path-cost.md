# Staff detour around keycard doors

Patch: `patches/keycard-door-path-cost.patch.json`.

## What you'll notice

Guards and other staff walked long detours rather than go through a keycard
door, even when they could open it. With the fix they go through the door.

## What changes

When the game plans a route, a keycard door no longer counts as a very long way
round. It now counts like any other locked door. Who may open a keycard door is
unchanged.

## Status

Tested in game on a player's save.
