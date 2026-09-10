# Gang contraband hand-off fix: technical notes

Target: `Prison Architect64.exe`, Steam Sunset Update (final build).
SHA256 `cc460fc435f2af4b1165f32cadde62b7943890ec8c9b2994e9f120830b2de1d9`.
The binary keeps RTTI and is linked without dynamic base, so every address
below is fixed at run time.

## Layout

| item | location |
|---|---|
| App global | `0x140D57900` |
| World | `*(App + 0x198)` |
| ContrabandSystem (embedded in World) | `World + 0x21A0`, size 0x1A0 |
| HandOffGuard (ObjectId .i/.u) | `+0x184 / +0x188` |
| HandOffGangMember | `+0x18C / +0x190` |
| chosenContraband | `+0x194` |
| handOffTimer (float) | `+0x198` |
| triedHandOffToday (bool) | `+0x19C` |
| Prisoner misbehaviour state | `prisoner + 0xA2C` (10 = ContrabandHandOff) |
| Prisoner sector index | `prisoner + 0xA34` |
| Regime table | `World + 0x5E8` (count `+0x5F4`, bypass flag `+0x5DC`) |

Functions (Ghidra names):

| function | role |
|---|---|
| `FUN_1404f6500` | ContrabandSystem constructor, registers the save fields |
| `FUN_1404f71c0` | ContrabandSystem per-tick update; picks a hand-off guard when the slot is empty |
| `FUN_1405dd780` | Guard hand-off routine, called from Guard update `FUN_1405d46e0` |
| `FUN_1406ae3c0` | Prisoner misbehaviour update; state switch has no case for 10 |
| `FUN_1406aee20` | SetMisbehaviour(prisoner, state); clears the escort ids at +0x324/+0x328 |
| `FUN_1406aed00` | ClearMisbehaviour(prisoner) |
| `FUN_1407badc0` | World::Resolve(World*, ObjectId*) |
| `FUN_1401c9710` | ObjectId equality |
| `FUN_1405c2ff0` | pick a random eligible gang member |

## Defects

1. State 10 has no handler in the prisoner misbehaviour switch, no timeout,
   and no prisoner-side exit. Each tick it re-asserts itself through
   `FUN_1406aee20`, which clears the escort ids, so any guard job on the
   prisoner is invalidated immediately.
2. In `FUN_1405dd780` the regime check (sector regime type must be 1 or 7)
   runs before the in-progress hand-off is serviced. A regime change strands
   the prisoner until the next free time.
3. In `FUN_1405dd780`, if the stored gang member does not resolve the routine
   returns without clearing it. The guard update returns right after the
   routine while contraband is held, so the guard also stops all normal
   duties.
4. Nothing clears `HandOffGuard` when the guard is fired or dies. The system
   only re-picks when the slot is -1, so the feature dies and the current gang
   member is orphaned.
5. When the system re-picks, it re-picks the gang member too, orphaning any
   prisoner already in state 10.

## Edits

Code cave: the zero padding at the end of `.text`, VA `0x140A44260`,
file offset `0xA43660`, 426 bytes available, section is executable.

| site | original | new | effect |
|---|---|---|---|
| `0x1405DD8DF` | `JZ 1405DDB85` | `JZ 1405DDB6C` | unresolvable member -> `HandOffGangMember = -1` then return |
| `0x1405DD8FF` | `JS 1405DDB85` | `JS stubA` | regime fail |
| `0x1405DD90C` | `JGE 1405DDB85` | `JGE stubA` | regime fail |
| `0x1405DD92B` | `JNZ 1405DDB85` | `JNZ stubA` | regime fail |
| `0x1406AEC19` | `CMP EAX,10; JNZ +0A` | `JMP stubB` | prisoner state-10 validity |
| `0x1404F7609` | `JNZ 1404F76B2` | `JNZ stubC` | system: guard slot set |

Stub A (`0x140A44260`): if `prisoner.state == 10` jump to the routine's own
reset tail at `0x1405DDB64` (ClearMisbehaviour + member = -1), else plain
return via `0x1405DDB85`.

Stub B (`0x140A4427A`): for state 10, re-assert only if
`World.HandOffGangMember == prisoner.id`, `Resolve(World.HandOffGuard) != 0`
and the sector regime type is 1 or 7 (or the `+0x5DC` bypass is set). Otherwise
`ClearMisbehaviour(prisoner)` and jump to the function epilogue at
`0x1406AECA7`.

Stub C (`0x140A44347`): when the guard slot is set, resolve it. Alive: continue
at `0x1404F76B2` as before. Gone: resolve the old member and clear him if he is
in state 10, set `chosenContraband = -1` and `handOffTimer = 0`, then fall into
the original pick code at `0x1404F760F`.

Registers relied on: `RBX` = prisoner in the guard routine and prisoner
update, `RBX` = ContrabandSystem in the system update, `RSI` = 0 on entry to
the pick code (callee-saved, untouched). All stubs run at the original call
depth, so alignment and shadow space are the caller's.

## Rebuilding and verifying

`scripts/Build-Patch.ps1` assembles the stubs with a two-pass mini assembler
and reads the expected bytes from the local executable (preferring the
`.orig` backup). `tools/ghidra-scripts/VerifyPatch.java` disassembles the hook
sites and the cave from a patched copy; the output should match the tables
above instruction for instruction.

The prisoner misbehaviour state is not serialised, so existing saves need no
editing; the jam is rebuilt from scratch each session in the unpatched game
and cannot form in the patched one.
