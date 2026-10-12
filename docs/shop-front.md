# Shops without prisoners inside (withdrawn)

Patch: `patches/shop-front.patch.json` (marked `withdrawn`). Uses the code
section (`code-section.md`).

Withdrawn on 2026-10-05: the problem could not be reproduced in the final game.
The patcher no longer offers or installs it, and removes it from a game file
that a test build (1.7.0 to 1.14.0) left it in. Dropping the `withdrawn` flag
brings it back unchanged.

## What it was meant to fix

Reports said prisoners could only buy from a shop front if they could walk into
the shop and were allowed in it. With the patch they would buy from the other
side of the counter, so the shop front could face a hallway and the shop could
stay off limits to customers.

## What it changes

When a prisoner cannot reach the shop front's own tile, or is not allowed
there, the game also accepts a tile next to it that the prisoner can reach and
is allowed on. Only objects built into a wall, such as the shop front, are
affected.

## Why it was withdrawn

The game checks the shop front's own wall tile. In both test saves that tile is
not part of the shop's sector, and the check passed every time without the
patch, so the patch never had anything to do:

- `base3z`: the shop zoned for one prisoner category, others buying from the
  hallway.
- `shopworktime`: as saved, with the shop zoned Staff only (no prisoner may
  enter), and with its only door walled up.

A save in which customers are refused at a shop front would reopen it.
