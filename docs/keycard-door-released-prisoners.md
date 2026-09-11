# Released prisoners stuck behind revoked keycard doors: technical notes

Target: `Prison Architect64.exe`, Steam Sunset Update. Same build and conventions
as `gang-handoff.md`; the router background is in `keycard-door-path-cost.md`.

## Symptom

A keycard door has "prisoner access revoked" (the per-door toggle; the save
field is `KeycardDoorAccess true`). It is the only door between a cell block
and the outside. When a prisoner's sentence ends they get the RELEASED
nameplate, drop everything, and then stand still indefinitely. Nothing ever
sends them to the exit and no guard is asked to open anything. Reported on the
community Discord with a test save (`keycardtest3local.prison`: two prisoners
with a one-day sentence fully served, standing idle in the cell block, one
large keycard door with access revoked).

## What the toggle means

The door's popup text: "Guards with a keycard or inmates wearing Tracker Belts
can pass through this door, though prisoner access can be revoked independently
for each door." So the door has three classes of user: staff with a keycard,
prisoners with a tracking belt (`Prisoner+0xA0C`, only with the Sunset DLC
`FUN_1401c6b50(0xD)`), and everyone else. "Revoked" is meant to remove the
second class.

The revoked flag lives on the door object (`Door+0x290` at run time, registered
as `KeycardDoorAccess` for the save) and is copied into the nav grid as
`cell[0xC]` ("staff-only keycard"), which is what the router reads.

## Where it goes wrong

`CanEnterCell` (`FUN_14061b6d0`) keycard branch, from `0x14061BD3A`:

```
14061bd3a  lea  eax,[rcx-0x247]      ; door type 0x247/0x248?
14061bd40  cmp  eax,ebp
14061bd42  ja   14061bd8c            ; no: other locked door
...
14061bd68  cmp  byte ptr [rsi+0xc],0 ; revoked?
14061bd6c  jz   14061bd78            ; no: continue
14061bd6e  test dil,0x4              ; movement flag bit 2 = staff key
14061bd72  jz   14061bfae            ; no staff key -> return 0 (cannot enter)
14061bd78  test al,al                ; bit 39 = prisoner with tracking belt
14061bd7a  jnz  14061bdbf            ; belt: pass at normal cost
14061bd7c  movss xmm0,[rbx]          ; else: fall into "needs a guard"
```

Every other locked door type ends up in the common tail: if the entity cannot
open the door itself the result is 3 ("needs a guard"), the step costs ten times
more, and the entity walks to the door and requests a guard (`FUN_14079b550`,
job type 0xD). The revoked-keycard test is the only place in the function
where a door is a hard wall for an entity that could otherwise be let through
by a guard.

That is fine for a prisoner serving time: the sector router simply never plans
through the door, which is what "revoked" should do. A released prisoner is a
different case. The game already treats them as no longer bound by the prison:
`Prisoner::IsReleased` (`FUN_1406afa00`, "served >= sentence and not in Escape
Mode") is what draws the RELEASED nameplate, and in the movement-flag builder
(`FUN_140540810`, case 0x6D) it is the only ordinary way a prisoner gets flag
**bit 7**, the "ignore deployment zones" bit that every non-prisoner carries.
The other two ways are the escort lists at `World+0x2CD8` (when `World+0x2CCC`)
and `World+0x2AC0` with state 5..7, whose members are also free to open staff
doors themselves in `Door::Open`. Released prisoners still do not get the staff
key (bit 2) or a tracking belt (bit 39), so at a revoked keycard door they are
refused outright. With no route to the map edge they never start walking.

## Fix

One byte at `0x14061BD6E`: the mask of the `test dil` becomes `0x84`, so the
refusal now reads "no staff key **and** not free to ignore zones". Entities
that pass the test continue exactly as before: prisoners with a belt open the
door themselves, everyone else gets result 3 and a guard is sent, the same as
for a jail door. The staff-key path is unchanged.

```
14061bd6e  40 F6 C7 04   test dil,0x04
     ->    40 F6 C7 84   test dil,0x84
```

Who is affected:

- Released prisoners (the bug): now route to the exit through the revoked
  door with a guard opening it.
- Prisoners on the two escort lists: same, consistent with them already
  bypassing deployment zones.
- Prisoners serving time: still refused (they never have bit 7).
- Prisoners with a tracking belt at a revoked door: still refused (the
  belt check comes after this test and a belt does not grant bit 7).
- Non-prisoners without the staff key (visitors, delivery men and so on):
  they all carry bit 7, so a revoked keycard door now behaves for them like
  an unrevoked one, "needs a guard". Before the patch it was a wall. The
  toggle is described as revoking prisoner access only, so this is treated
  as the intended meaning rather than a side effect.

The door-side check is unaffected: `Door::Open` (`FUN_140526a90`) still refuses
a beltless prisoner at a keycard door; what opens the door for a released
prisoner is the guard, as with any locked door.

`scripts/Build-KeycardDoorRelease.ps1` generates the patch;
`patches/keycard-door-released-prisoners.patch.json` is the result. Verified by
disassembling a patched copy and confirmed in-game on the reporter's save
(2026-09-10): both released prisoners walked to the door, a guard opened it,
and they left.

## Not covered

A revoked keycard door that is the only exit still costs a released prisoner
the usual "needs a guard" wait, so the exit is only as fast as the nearest
free guard. If the report comes back as "they start walking but never get
through", the next place to look is the guard side of the door-open job
(`FUN_14079b550`, job 0xD) and `Door::Open`'s deployment branch.
