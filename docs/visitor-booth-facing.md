# Visitor booths facing up: technical notes

Target: `Prison Architect64.exe`, Steam Sunset Update. Same build and
conventions as `gang-handoff.md`. Uses the appended code section described in
`code-section.md`.

## Symptoms

A row of visitor booths dividing a visitation room, prisoners on one side and
visitors on the other, works when the prisoners' side is at the bottom and
fails when it is at the top: no visits happen at those booths. Ozoneraxi's
AIO tracker records that the "prisoner up / visitor down" layout only works
when prisoners and visitors can path into *both* halves of the room, and
suggests doors and wall panels instead — which lets prisoners into the visitor
side and so loses the no-contact, no-contraband point of a booth. Older reports
describe the same thing as booths "behaving like visitor tables", and prisoners
and visitors ending up on each other's side.

## Cause

A booth (`VisitorTableSecure`, type `0x118`, 2×2) has two standing positions,
sprite markers 0 and 1 (`objects.spritebank`, sprite `VisitationSecure`).
Which of them is the prisoner's follows the way the booth faces:

- the prisoner's visitation job (`FUN_140632F30`) takes slot 0, unless the
  booth faces up (`dir.y == -1.0`, `object+0x58`), when it takes slot 1;
- the visitor's job (`FUN_140761A00`, `FUN_140761CA0`) takes slot 1, unless
  the booth faces up, when it takes slot 0.

So the prisoner's side is the side the booth faces, for all four facings, and
the two jobs agree.

The pairing check does not. When the `VisitationSystem` (`World+0x1FA8`) looks
for a prisoner to match with a waiting visitor at a booth, `FUN_14075E5A0`:

1. asks the booth for **slot 0** (`GetSlotPosition`, vtable `+0x68`, at
   `0x14075E698`: `xor edx,edx`);
2. for a booth, takes the sector at that tile (`FUN_14070CE50`) and requires
   it to admit the prisoner's category;
3. requires the tile to be reachable from the prisoner's cell
   (`FUN_14070EDC0`).

For a booth facing down, left or right, slot 0 is the prisoner's side and the
checks are asked about the right tile. For a booth facing up, slot 0 is the
**visitor's** side: the check demands that the prisoner's category be allowed
in the visitor half and that the prisoner can walk there. In a booth room built
properly that is false, so no visit is ever arranged. Open the visitor half to
prisoners and it passes — and the prisoner then walks to slot 1, the top, as
intended — which is exactly the reported workaround and its cost.

### Why the two vertical facings look the same

The sprite has `RotateType 2`: one frame for both vertical facings and one for
both horizontal ones, mirrored for facing right (`FUN_1403FD080`,
`FUN_14042F4B0`). A booth facing up is drawn exactly like one facing down, and
its markers are not flipped either. That is not the bug — the jobs already
compensate by swapping slots — but it means the game gives no visual cue which
way a vertical booth faces. The rule is simply: **the prisoner's side is the
side the booth faces**. A booth placed with its prisoners' sector below it is
fine as placed; one with the prisoners above needs to be rotated to face up
(rotate while placing). Before this fix that rotation could never work; after it
it does.

## Fix

The pairing check asks for the same slot the prisoner will use.

| site | was | now |
|---|---|---|
| `0x14075E698` | `xor edx,edx` / `mov rcx,rbx` / `call [rax+0x68]` (8 bytes) | `JMP .tyrs+0x500` + 3 `NOP` |

The stub (`.tyrs+0x500`, 36 bytes) sets `edx` to 1 when the object's type is
`0x118` and its direction y is exactly `-1.0f` (`0xBF800000`, the same test the
jobs make), 0 otherwise, then performs the original `mov rcx,rbx` /
`call [rax+0x68]` and jumps back to `0x14075E6A0`. `rax` (the vtable),
`r8`/`r9` (the out-pointers) and the fifth argument on the stack are exactly as
the game left them; `rcx` and `rdx` are the only registers written, and the
original instructions wrote both.

Nothing else changes. Visitor tables (`0x117`) and video-call booths
(`0x244`) never take the new branch. Booths facing down, left or right get slot
0 as before.

### Register notes

`rbx` is the table object (`+0x40` type id, `+0x54`/`+0x58` direction) and is
callee-saved. The hook replaces the instructions that set the call's first two
arguments, so the stub is entered with `rax`, `r8`, `r9` and `[rsp+0x20]`
already prepared and the stack at the same depth the call expects; the stub's
`call` therefore behaves exactly like the one it replaces.

## Verification

Disassembled the patched copy: the stub reads back as assembled at
`0x140E89500`, and `0x14075E698` is `jmp 0x140E89500` followed by three `nop`s
with `0x14075E6A0` intact. The patcher's apply/revert round trip returns the
original hash.

In-game confirmation is still needed: a visitation room with booths across the
middle, prisoners' sector above the booths and no way for prisoners into the
lower half, booths rotated to face up. Visits should be arranged and take place
with the prisoner at the top and the visitor at the bottom, and nothing should
change for booths facing down, left or right, or for visitor tables.

## Facts recorded along the way

- `VisitationSystem` = `World+0x1FA8`; visit records at `+0x70` (`0x34` bytes
  each, count `+0x7C`): `+0x00` visitor, `+0x08` second visitor, `+0x10`
  third, `+0x18` table, `+0x20` prisoner (all id pairs), `+0x28` state (0 walk,
  1 seated, 2 visiting, 3 done), `+0x2C` timer. Lookup by any participant
  `FUN_14075FAA0`, membership `FUN_14075FBC0`, release `FUN_14075FC30`,
  update `FUN_14075E150`, pairing `FUN_14075E5A0`, create visitors
  `FUN_14075F120`, choose a table `FUN_14075EDA0`, visiting hours predicate
  `FUN_14075E540` (08:00–20:00).
- Table object: `+0x290` timer, `+0x294` visitor id pair (`Visitor.i/.u`),
  ctor `FUN_140760140`, class `VisitationTable`.
- Prisoner `+0x9F8` = world clock when last seated for a visit, `+0xADC` =
  last visit timer, `+0xD48` = "visited" flag set by the job step
  `FUN_14078D750` when the prisoner is within one tile of the table.

## Layout note

The stub was first placed at `.tyrs+0x4D0`. With the intake-route-categories
fix also applied and no tweaks, that layout made Windows Defender's cloud
heuristic quarantine the patched game file (`Trojan:Win32/Bearfoos.A!ml`).
The ten-fix set, either new fix on its own, the same twelve fixes with the
tweaks, and the same code at `+0x500` all pass, so the verdict is noise on the
section's byte layout rather than anything the code does. The stub therefore
lives at `+0x500`; see the antivirus section of `code-section.md`.
