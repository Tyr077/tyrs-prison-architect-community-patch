# Staff detour around keycard doors: technical notes

Target: `Prison Architect64.exe`, Steam Sunset Update. Same build and conventions
as `gang-handoff.md`.

## Symptom

Guards and other staff walk long detours rather than pass through a keycard
door, even when they hold the key and the door is right in front of them.
Reported on the official forum ("Guards/staff take giant detours instead of
going through key card doors") and on the community Discord, with a test save
(an office with a double staff door on one wall and a large keycard door on the
other, guards deployed on both sides).

## Where the route cost comes from

`CanEnterCell` (`FUN_14061b6d0`) is called by the A* router
(`FUN_1406fb990` via the nav-grid wrapper `FUN_1406fc880`) and by the
sector-level helpers for every step from one cell to a neighbour. It takes the
entity's movement-flag word (`FUN_140540810`, see `visitor-door-access.md`) and
the nav cell of the target (`0x60` bytes per cell in the grid at
`NavGrid+0x158`), returns 0 for "cannot enter", 1 for "can", 3 for "can, but a
guard has to open the door", and writes the step cost to an out parameter.

For a cell that holds a door (`cell[5]`, door type at `cell+8`) the relevant
part is, in order:

1. `unlocked = IsUnlockedDoorType(type) || World+0x4611 == 0`
2. staff-door types and `0x216`: needs the staff key (flag bit 2) unless unlocked.
3. **keycard doors `0x247`/`0x248`** (`0x14061BD3A`):
   - `canOpen = unlocked || bit 2 (staff key) || bit 39 (prisoner with keycard)`
   - if the door is marked staff-only (`cell[0xc]`, from the door's
     `KeycardDoorAccess` field) and the entity has no staff key: return 0.
   - if the entity is not a keycard-holding prisoner: **`cost += 1000`**
     (`0x14061BD82`, `addss xmm0, xmm5`, `xmm5 = DAT_140B1BE84 = 1000.0`),
     then fall through to the guard test.
4. every other locked door: `canOpen = unlocked || bit 1 (general keys)`.
5. common tail: if `!canOpen`, `cost = max(cost, 1) * 10` (plus 1000 if flag
   bit 18, "recently stuck at a door", is set) and the result becomes 3.

So a jail door costs a key holder nothing extra and everyone else ten times the
step; a keycard door costs a key holder **a thousand** and everyone else ten
times that. The constant is the same one used for swimming across water, which
is the game's way of saying "only if there is no other way". A guard on the
wrong side of a keycard door will therefore walk up to a thousand tiles to
avoid it. The route cost is not shown anywhere, which is why this looks like
the door "not working".

Constants, for reference: `DAT_140B1BE84` = 1000 (keycard door, swimming,
stuck-at-door), `DAT_140B1BC4C` = 10 (needs-a-guard multiplier),
`DAT_140B1BDFC` = 200, `DAT_140B1BD18` = 50, `DAT_140B1BBC4` = 5,
`DAT_140B1BC90` = 20, `DAT_140B1B2B4` = 0.1 (one-way and other modifiers).

## Fix

The four bytes of the `addss` at `0x14061BD82` become a 4-byte NOP. Keycard
doors then go through exactly the same guard test as jail doors: staff with the
staff key pass at normal cost, prisoners with a keycard pass (unless the door is
staff-only), everyone else gets the "needs a guard" cost and a guard is sent.
The 1000 constant is untouched, so swimming and the stuck-at-door penalty are
unchanged. The `movss`/`movss` pair around the NOP now stores the cost back
unmodified.

Not changed: whether a given entity may *open* a keycard door (that is
`Door::Open`, the "locked door" block, and was already correct for staff), and
the A* itself, which has no cost cap, only a per-frame time slice
(`NavGrid+0x188`) and fails only when the open list runs dry
("AdvanceRouting failed to find a route").

`scripts/Build-KeycardDoorCost.ps1` generates the patch;
`patches/keycard-door-path-cost.patch.json` is the result.

## The "only route" report

The Discord report also said that when a keycard door is the *only* route,
nothing goes through it at all. Nothing in the router explains that as a
separate bug: the A* has no cost cap, so the search still succeeds, just after
expanding every cheaper cell first. With this patch applied, the reporter's
test save (an office whose south exit is a large keycard door, guards deployed
beyond it) routes the guards straight through the door, and the "only route"
behaviour could not be reproduced. It is treated as the same defect. If it
comes back, the next places to look are the sector-level routing
(`FUN_140682050`, `FUN_140684330`) and the deployment branch of `Door::Open`
(`FUN_1401c6b50(3,1)` with `World+0x4715`), which only lets guard types with an
assigned position open locked doors.
