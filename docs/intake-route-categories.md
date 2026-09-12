# Intake routes that accept only some categories: technical notes

Target: `Prison Architect64.exe`, Steam Sunset Update. Same build and
conventions as `gang-handoff.md`. Uses the appended code section described in
`code-section.md`.

## Symptoms

Logistics > Transport lets each road, helipad and boat dock accept only some
prisoner categories. Prisons that use that — a helipad for Max Sec, the road for
everyone else, say — find after a while that nobody arrives any more. The
sidebar says *Your prison is closed to new inmates* although cells stand empty
and intake is set to Fill Capacity or Total Prisoners. The only known recovery
was to set every route to accept every category and force the queue to refill
(remove intake restrictions, untick Prisoner Replacement, re-zone cells).

Ozoneraxi's test matrix on the AIO tracker pins it down: any route that accepts
only some categories breaks it; routes that accept everything, or are switched
off entirely, do not.

## Cause

Two bookkeeping systems have to agree about how many prisoners are on their
way.

The **intake system** (`World+0x1778`) keeps, per category, a `Queue` count of
prisoners waiting to be delivered (`categoryEntry+0x14`, entries of `0x1C`
bytes at `+0x298`, count `+0x2A4`). Each day `FUN_140665110` moves the day's
`NextIntake` into `Queue` and, for the total, tells the **arrival system**
(`World+0x600`) to expect that many prisoners (`FUN_140734CF0(sys, 0x6D, n)`;
the per-type pending count is at `sys[0][type]`, so prisoners are
`+0x1B4`).

The **dispatcher** (`FUN_1407333A0` → `FUN_140733AF0`) honours the route
settings. It offers the queued counts, laid out by category, to each stop in
turn — helipad, then boat dock, then the road (`FUN_140731750`,
`FUN_140515400`) — and picks the first that accepts a category with something
queued. It then loads the vehicle with exactly the number queued in the
categories that stop accepts (`FUN_1407326C0`, capped at the vehicle's
capacity) and creates each prisoner through `FUN_140608A30`, passing the
stop's accepted set (nine bytes, one per category, built by `FUN_140516280`).

The **creation step** does not honour it. `FUN_140608A30` asks the intake
system for the next queued prisoner:

```c
p = new Prisoner();
while (p->category == 0 || !accepted[p->category])
    IntakeSystem::AssignQueuedCategory(intake, p);        // FUN_140665370
```

`FUN_140665370` always hands out the **first** category in the list that has
anything queued, and decrements that category's `Queue`. If the stop does not
accept that category, the loop just asks again. Every rejected draw has already
removed one queued prisoner of another category. That prisoner is never
created, but the arrival system still expects it.

From there the failure is mechanical. A pending prisoner counts against
capacity: `FUN_140665F10` returns
`capacity − pending − present − …`, and `FUN_140665020` (the predicate behind
`objective_intake_closed`) reports Fill Capacity as closed when it is not
positive. Once the queue is empty, no stop accepts anything, so nothing is
dispatched and the phantom pending count never drains. Each day's intake adds a
few more, until capacity is exhausted on paper and the prison closes with empty
cells — the "several saves after about ten hours" in the reports.

The trigger is a stop that accepts only some categories **and** a category it
rejects sitting ahead of one it accepts in the intake list (the list order is
the order categories were added, Min Sec first). That is why "partial anything"
breaks it and "all or nothing" does not.

When the queue is empty but the vehicle still has room, `FUN_140665370` logs
`no prisoners are queued for intake` and invents a Min/Med/Max Sec category at
random. That is what makes the discarded prisoners "arrive" as other categories
sometimes, and also why a route that accepts none of those three is not merely
broken but a hang: the loop never finds an acceptable category. This patch does
not change that path; it makes it far less likely to be reached, because the
vehicle is only ever loaded with prisoners that really are queued for it.

## Fix

While `FUN_140608A30` is drawing for a stop, `FUN_140665370` prefers the first
queued category the stop accepts.

| site | was | now |
|---|---|---|
| `0x140608A91` | `CALL FUN_140665370` | `CALL .tyrs+0x4A0` (wrapper) |
| `0x1406653C2` | `mov eax,esi` / `cmp [r11+0x2a4],eax` / `jle` (11 bytes) | `JMP .tyrs+0x410` (scan) + 6 `NOP` |

The **wrapper** (`.tyrs+0x4A0`, 35 bytes) stores the stop's accepted-set
pointer (`[rdi]` at the hook) in `.tyrs+0x018`, makes the original call, and
clears the pointer again. The unfiltered spawner `FUN_140608780` calls
`FUN_140665370` directly and so always sees a null pointer.

The **scan** (`.tyrs+0x410`, 115 bytes) sits at the head of the search loop.
With no pointer set, or nothing queued, it re-executes the three replaced
instructions and continues into the original loop from index 0. Otherwise it
walks the category list looking for the first entry with `Queue != 0` whose
category the set accepts (categories 0..8; anything else is skipped), and on a
hit jumps into the original loop body at that entry with `eax`/`rcx` set to its
index and byte offset. The loop then finds the entry non-empty and takes it
exactly as it would have — same decrement, same `NumNITGs` handling, same
special-prisoner and death-row follow-ups. Entries the scan passes get the same
side effect the original loop gives them (a category-8 entry has its `NumNITGs`
cleared), so the two paths are indistinguishable except for which entry is
chosen. If nothing accepted is queued the original loop runs unchanged, which
keeps the existing behaviour, including the random fallback, for the corner case
where the dispatcher's snapshot of the queue is stale.

The net effect: a vehicle takes the queued prisoners of the categories its stop
accepts and leaves the rest queued for a route that does, and the intake queue
and the arrival system's pending count stay in step.

### What this does not do

A category that **no** route accepts still sits in the queue for ever, and its
prisoners still count against capacity. That is a configuration the game lets
you make and gives no warning about; before this patch such prisoners were
silently turned into whatever category the first vehicle wanted, which hid the
problem behind a different one. If intake closes with cells free, check that
every category with a ratio above zero is accepted by at least one route.

### Register notes

At the loop head `r11` is the intake system, `rbx` the prisoner, `esi` is
zero and `r8b` is a flag the loop may set and tests afterwards; `eax` and
`rcx` are the loop's index and byte offset. `r9` and `r10` are written before
they are next read (`0x14066549A`, `0x1406654FB`), so the scan uses them and
`r8d` as scratch and re-zeroes `r8b` on both exits. The wrapper is entered by a
`CALL` from a frame that is 16-byte aligned, so it opens `0x28` bytes: 8 to
restore alignment for its own call and 32 for the callee's home area, which
`FUN_140665370` writes into (`mov [rsp+0x70],rbx` after its `push`/`sub`).

## Verification

Disassembled the patched copy: the scan and wrapper read back as assembled at
`0x140E89410` and `0x140E894A0`; `0x1406653C2` is `jmp 0x140E89410` followed by
six `nop`s and the loop body at `0x1406653CD` is intact; `0x140608A91` calls
`0x140E894A0`. The patcher's apply/revert round trip returns the original hash.

In-game confirmation is still needed: set up one route that accepts only some
categories and another that accepts the rest, run Fill Capacity for several
days, and check that prisoners of both kinds keep arriving and the sidebar never
reports intake closed while cells are free.

## Facts recorded along the way

- Transport stop object: `DeliveryStop` record at `object+0x258` with
  `DeliveryZones +0x08`, `GarbageZones +0x18`, `ExportZones +0x28`,
  `IntakeZones +0x38`, a registry at `+0x88`, and the accepted-class flags at
  `+0x50` (count `+0x58`, 16 slots). The road's record is `World+0x3038`.
  Helipad `0x16C`, FerryDock `0x16D`, BoatDock `0x16E`; PrisonerBus `0x8C`,
  PrisonBoat `0x97`, PrisonHeli `0x98`.
- Flag slots map to categories through the table `FUN_140516280` builds:
  category 1→slot 4, 2→5, 3→6, 5→12, 6→7, 7→8, 8→13. `FUN_140733F40`
  writes the per-category `Queue` counts into those slots of the class array
  the dispatcher offers to the stops.
- Arrival system `World+0x600`: `sys[0]` pending per type, `sys[0xC]` and
  `sys[0xF]` running totals; `FUN_140733F40` is its hourly update,
  `FUN_1407352E0` the automatic purchases.
- Intake category entry: `+0x00 PrisonerCategory`, `+0x08 Pool`, `+0x0C Ratio`
  (the intake slider), `+0x10 NextIntake`, `+0x14 Queue`, `+0x18 NumNITGs`;
  `+0x04` is not saved.
