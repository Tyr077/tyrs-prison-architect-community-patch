# Visitors and civilians stuck at visitor doors: technical notes

Target: `Prison Architect64.exe`, Steam Sunset Update. Same build and conventions
as `gang-handoff.md`.

## Symptom

Reformed prisoners (Second Chances mentors), animal therapists, fire safety
teachers, delivery men and some other event-spawned NPCs walk up to a visitor
door or visitor gate and stop. They never open it and no guard is sent to open
it for them. The same NPCs get through double visitor doors, because a guard
turns up. The report came from the community Discord, together with a
save-side workaround that changes what the entities have stored on them.

## Two functions disagree

`Entity::TryPassThroughDoor` (`FUN_140533ff0`) runs when an entity reaches a
door on its path. For each door on the tile it:

1. calls `Door::Open` (`FUN_140526a90`, its only caller) with the entity;
2. decides whether the entity is able to open the door **by itself**, from the
   movement-flag word returned by `FUN_140540810` (or'd with the caller's
   extra flags);
3. if not, asks the job system for a guard (`FUN_14079b550`, job type `0xD`,
   "open this door").

Step 2, for the visitor-door types, is (`0x140534596`):

```
cmp ecx, 0x2b        ; VisitorDoor
jz  visitor
cmp ecx, 0x18        ; FenceGateVisitor
jz  visitor
...                  ; everything else, including DoubleVisitorDoor 0x1A9:
test al, 2           ;   needs the "general keys" bit
...
visitor:
test qword [rsp+0x68], 0x8000002   ; keys bit OR visitor-access bit 27
```

and `FUN_140540810` sets bit 27 for every entity whose type is not `Prisoner`
(`0x6D`), unconditionally (`flags |= 0x8000080` whenever `type != 0x6d`, near the end
of the function). So for a plain visitor door, every non-prisoner "can open it
itself" and no guard is ever requested. For a double visitor door the code
falls into the generic branch, the visitor lacks the keys bit, and a guard is
requested; that is why double doors work.

Step 1 has its own opinion. `Door::Open` groups doors by type; for the
visitor-door class (`VisitorDoor 0x2B`, `FenceGateVisitor 0x18`,
`DoubleVisitorDoor 0x1A9`, or definition access class 2 at `ObjectDef+0x12C`)
it refuses the entity unless (`0x140526DB2`):

| check | who passes |
|---|---|
| `bt 0x1FB3445, type-0x6A` | RiotGuard, EliteOps, Paramedic, Fireman, Actor, Visitor, Teacher, Soldier, 0x7D, ParoleOfficer, ParoleLawyer, AppealsLawyer, AppealsMagistrate, ExecutionWitness |
| `type == 0x214` | Waterman |
| `bt 0x80000000000101, type-0x1C0` | RestaurantCustomer, CivilianChild, PestControlTeacher |
| `type == 0x235` | GymInstructor |
| `FUN_1407dd630(type)` | any type with the staff flag (`ObjectDef+0x98` bit 8) |
| `r13b` / `r15b` | escape-mode player control, and the per-entity override byte at `+0x309` |

Everything else returns without opening. The list was never extended for the
later DLC entities. Not on it, and not staff:

| type | name |
|---|---|
| `0x1BF` | AnimalTherapist |
| `0x1C2` | RehabilitatedPrisoner (the "reformed prisoner" mentor) |
| `0x1FD` | FireSafetyTeacher |
| `0x20E` | EntityDeliveryMan |
| `0x1EE`, `0x208`, `0x215` | PestControlWorker, Repairman, GritterDriver (callouts usually set the `+0x309` override, which is why they work when spawned by an event and not from the cheat menu) |

So the entity is told it can open the door, tries, is refused, and never asks
for help.

The object type ids come from the name table at `0x140E03A40` (0x20-byte
entries, filled in by `FUN_1400ac830`); the id is the entry index.

## Fix

Replace the allow-list test with the rule the movement flags already use:
refuse only prisoners. At `0x140526DBA` the 8 bytes

```
8D 41 96    lea eax, [rcx-0x6a]
83 F8 18    cmp eax, 0x18
77 0A       ja  0x140526DCC
```

become

```
83 F9 6D    cmp ecx, 0x6d          ; entity type == Prisoner?
75 4F       jnz 0x140526E0E        ; no: allowed
EB 0B       jmp 0x140526DCC        ; yes: run the remaining original checks
90          nop
```

For a prisoner the remaining checks (Waterman, the 0x1C0 range, GymInstructor,
staff flag, overrides) all fail as before, so prisoners are still refused
unless an override applies. For everything else the outcome is "allowed",
which is what `TryPassThroughDoor` assumed all along. The old `mov edx / bt /
jc` at `0x140526DC2` is left in place and is unreachable.

Zombies never reach this code for locked doors (they have their own branch in
`TryPassThroughDoor`), and the escape-mode and keycard-door rules in the other
blocks of `Door::Open` are untouched.

`scripts/Build-VisitorDoor.ps1` generates the patch; `patches/visitor-door-access.patch.json`
is the result. Verified by disassembling the patched copy.

## Not covered

- Keycard doors (`0x247`/`0x248`) use the "locked door" block of `Door::Open`
  (staff, key holders, prisoners with a keycard) and were not part of the
  report.
- A guard is still not requested for a visitor door when the entity really
  cannot open it (a prisoner without an override). That is the original
  behaviour and prisoners are not supposed to be on that side of a visitor
  door.
