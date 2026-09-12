# Shops usable from outside the shop: technical notes

Target: `Prison Architect64.exe`, Steam Sunset Update. Same build and
conventions as `gang-handoff.md`. Uses the appended code section described in
`code-section.md`.

## Symptoms

A shop is built, staffed and stocked, prisoners have free time and money, and
nothing is ever bought. Or it serves one wing and not another. The community
answer has always been some form of "make the inside of the shop reachable and
permitted for the customers" — put the shop front on a wall zoned as part of the
Shop, cut a door into the shop from each sector, or tag a dummy room on the far
entrance. The wiki says to place the front "inside the Shop room in a partially
dividing wall", noting this "requires prisoners to enter the room to make
purchases", which defeats the point of a serving hatch.

## Cause

A need provider's stored position is where the game expects the user to stand.
`NeedsLibrary::Update` (`FUN_1406609C0`) sets it, for `ProviderType Object`,
from the object's own position (`obj+0x48`), and replaces it with a real
standing position **only when the provider declares a `Slot`**:

```c
slot = def->Slot;                                   // providerDef+0x2C, default -1
if (record->BroadcastSlotId != -1) slot = record->BroadcastSlotId;
if (slot != -1) obj->GetSlotPosition(slot, &pos, &dir, 0);   // vtable +0x68
record->Pos = pos;                                  // record+0x14 / +0x18
```

Slots are **markers baked into the object's sprite**:
`WorldObject::GetSlotPosition` (`FUN_1407E01D0`) asks
`SpriteBank::GetMarkerOffset` (`FUN_1403FD990`) for marker *n* inside the
sprite's atlas rectangle, and interpolates it across the object's bounds.

The `Shopping` provider in `data/needs.txt` declares no `Slot`, and — checking
the `BEGIN Markers` table in `data/objects.spritebank` against each sprite's
rectangle — **`ShopFront` has no markers at all**:

| sprite | atlas rect | markers |
|---|---|---|
| `VisitorTable` | x34..40 y33..37 | 4 |
| `VisitorTableSecure` | x35..39 y29..33 | 2 |
| `WeightsBench` | x11..13 y16..19 | 2 |
| **`ShopFront`** | **x50..54 y44..46** | **0** |

So a shop front's standing position is the shop front itself — a tile the
object occupies, and the object is `Properties BuiltOnWall`. Provider validity
`FUN_140623D50` then asks both of its questions about that tile:

| check | function | reason code |
|---|---|---|
| region connectivity from the entity | `FUN_14070E6A0(sys, px, py, ex, ey, 0)` | `0xD` |
| sector permission for the entity | `FUN_14070EFE0(sys, px, py, entity)` | `0x17` |

Which is exactly the reported behaviour: the prisoner must be able to walk into
the shop, and be allowed in it, to buy anything over the counter.

## Why a mod cannot fix it

The obvious data fix is `Slot 0` on the `Shopping` provider. It does nothing:
with no marker for that index, `GetSlotPosition` falls through to enumerating
the object's own tiles and hands back the same wall tile. There is no standing
position anywhere in the game's data for a shop front, and a mod cannot add a
sprite marker.

## Why not fix the position instead

A provider record stores **one** position, shared by every consumer. A shop
front serving two sectors from opposite sides needs a different answer for each,
so no choice of position is correct. The check that has to change is the
per-consumer one.

## Fix

Both calls in `FUN_140623D50` are 5-byte `CALL`s and are redirected to stubs:

| site | was | now |
|---|---|---|
| `0x140623DCD` | `CALL FUN_14070E6A0` | `CALL .tyrs+0x320` |
| `0x140623EDD` | `CALL FUN_14070EFE0` | `CALL .tyrs+0x3A0` |

Each stub performs the original check unchanged and returns its result if it
passed. If it failed, and the provider's object is `BuiltOnWall`, it calls
`TryNeighbours` (`.tyrs+0x250`), which walks the four tiles around the
provider's position and returns true for the first that is **both** reachable by
this entity and permitted to it. Standing next to a serving hatch is what using
one means.

Both stubs use the same predicate, so the two checks cannot disagree about which
side the prisoner is on.

Nothing else changes. The provider's stored position is untouched, so pathing
and animation are unaffected — the prisoner walks to the counter and ends up
adjacent to it exactly as they do in a shop that works today.

### The BuiltOnWall guard

`providerDef+0x24` is the object type id; `ObjectDef` is
`DAT_140DECCA0 + id * 0x198` (count `DAT_140E085CC`), and `+0x98` is the
property bitmask. The property order is the table built by `FUN_14007CB90` at
`DAT_140DEC330`, in which `BuiltOnWall` is index 24 — cross-checked against the
already-known bit 8 (`Staff`) used by `IsStaffType`.

The guard is what keeps this narrow. Without it the relaxation would also apply
to, say, a bed in a room the prisoner may not enter, which would be a real
behaviour change. With it, the only providers that reach the new code are ones
that cannot work at all today.

### Register notes

At both hooks `rsi` is the provider definition, `r14`'s `+0x20` is the entity,
`rdi` is the provider record and `rbx` the reason-out pointer; all are
callee-saved and survive the stubs. Because each stub replaces a `CALL`, the
arguments the game set up are already in place. The reach stub reaches the
caller's 5th and 6th stack arguments at `+0x70` and `+0x78` once its own
`0x48` frame is open. `TryNeighbours` saves seven registers and takes `0x40`,
which keeps `rsp` 16-byte aligned for the calls it makes.

## Verification

`analysis/verify-shop-front.txt` is the disassembly of a patched copy at both
hooks and all three stubs. Built by `scripts/Build-ShopFront.ps1`, which also
refuses to emit overlapping blocks in the code section.

Not yet confirmed in a running game against a save that reproduces the original
symptom.
