# Exercise on equipment counts for grading: technical notes

Target: `Prison Architect64.exe`, Steam Sunset Update. Same build and
conventions as `gang-handoff.md`. Uses the appended code section described in
`code-section.md`.

## Symptoms

A prisoner's **Health** grade on the Grading tab scores `% of stay exercising`,
one point per 5%, on a scale of −5 to +5. Prisons whose prisoners exercise on
gym equipment score zero on that line no matter how much time the prisoners
spend working out. Players have reported it since 2015 in the form "all my
inmates completely satisfy their exercise requirements but never get any points
for this category".

It is not only cosmetic: every negative Health rating adds 5% to a prisoner's
re-offending chance, up to 25%.

## Cause

Time is accumulated by the prisoner's Experience object (`Prisoner+0xE60`),
whose counter array at `+0x10` holds 28 floats named by the table at
`DAT_140de0da0`. `Experience::Tick` (`FUN_1405889d0`, called from
`FUN_140588150` every 15 in-game seconds) credits exactly **one** counter per
tick, chosen from the prisoner's current ActionType at `Prisoner+0xDE0`:

| ActionType | counter |
|---|---|
| `0xB` Work | 7 Work |
| `0xE` ReformProgram | 9 Class |
| `8` Exercise | **8 Exercise** |
| anything else | 10 Freetime (regime FreeTime/Work) or 5 Regime |

Which activity a prisoner is performing comes from the need provider they are
using, defined in `data/needs.txt` and `data/needs_dlc.txt`. Exactly one
provider in the whole game carries `ActionType Exercise`:

```
BEGIN Provider                    BEGIN Provider
    Action        Exercise            Action        LiftWeights
    ProviderType  Room                ProviderType  Object
    Room          Yard                Object        WeightsBench
    PrimaryNeed   Exercise            PrimaryNeed   Exercise
    ActionType    Exercise            ActionType    Use
END                               END
```

Every piece of equipment — weights bench, treadmill, punch bag, gym mat,
dumbbell rack, tyre apparatus, training dummy, pull-up bar, and the rest of the
DLC set — declares `PrimaryNeed Exercise` with `ActionType Use`. So the game
knows perfectly well that the prisoner is exercising (it discharges the
Exercise need), but the Experience tick reads the action rather than the need
and files the time under Freetime or Regime.

The result is that only jogging laps around a Yard room ever scores the
criterion, and an indoor gym cannot score it at all.

## Fix

The hook is the ActionType 8 test, 9 bytes at `0x140588B23`:

```
83 F8 08     cmp eax,8
75 04        jne +4          -> 0x140588B2C, the regime/freetime branch
8B F8        mov edi,eax     -> counter slot 8
EB 3A        jmp 0x140588B66 -> the shared tail that adds the tick
```

They become `jmp` to a 116-byte stub at `.tyrs+0x1D0`, plus a 4-byte `nop`. The
stub keeps the original test and adds a second one: **ActionType `1` (Use) also
counts as exercise when the provider being used declares `PrimaryNeed
Exercise`**. It reaches the provider the way the rest of the game does —
`NeedSystem.Target` at `Prisoner+0xDE4` resolved by `FUN_14065F6D0` against the
list at `World+0x1b60`, the record's `+0x08` indexing the definition table at
`World+0x1ba8` (`0x80` stride, count `World+0x1bb4`), where `+0x40` is
`PrimaryNeed` and `7` is Exercise.

Reading the definition rather than naming objects means DLC and modded exercise
equipment are covered without listing anything.

The test stays keyed on ActionType Use on purpose. Three DLC providers pair
`PrimaryNeed Exercise` with `ActionType Work` (prison-labour rooms that also
work the prisoner's body); those still credit the Work counter, so work
experience is unaffected.

### Register notes

At the hook `eax` is the ActionType, `r9` the prisoner, `r8` the `App` pointer,
`edi` the counter slot chosen so far, `esi` the regime slot and `rbx` the
Experience object. `r8` is volatile and is read again at the return point
`0x140588B66`, so the stub reloads it from the `App` global after the call;
`rbx`, `rsi`, `rdi`, `xmm6`, `xmm7` and `xmm8` are non-volatile and survive it.
The function's frame is `push rbx; sub rsp,0x50`, so `rsp` is 16-byte aligned in
the body and a further `sub rsp,0x20` gives the call its shadow space while
keeping the alignment the ABI requires.

The provider index is bounds-checked with an unsigned compare, so a negative
index fails it too, and a stale or missing target simply falls through to the
original behaviour.

## Why this is not a mod

The community workaround would be to retag the equipment providers as
`ActionType Exercise` in `needs.txt`. That does make the time count, but the
ActionType also selects the animation, so prisoners would stop using the
equipment on screen and mime jogging on top of it. Fixing the grading side
instead leaves every animation intact.

## Verification

`analysis/verify-exercise-grading.txt` is the disassembly of a patched copy at
the hook and the stub. Built by `scripts/Build-ExerciseGrading.ps1`; the
addresses and struct offsets it uses are in `analysis/binary-facts.md`.

Not yet confirmed in a running game against a save that reproduces the original
symptom.
