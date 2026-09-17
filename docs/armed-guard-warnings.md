# Armed guard warnings with Staff Needs: technical notes

Target: `Prison Architect64.exe`, Steam Sunset Update. Same build and conventions
as `gang-handoff.md`. In place, no code section needed.

## Symptom

With Staff Needs enabled, armed guards rarely shout a warning before they open
fire, even when the guard's own needs are met. How often they warn follows the
prison's overall staff morale: at 0% they never warn. With Staff Needs off they
warn as they always did. Reported as GitHub issue #1.

## Cause

A guard's combat step, `FUN_1405D7680`, decides once per engagement whether to
shout (`FUN_1405DC370`, which calls the prisoner's OnWarnedBy and usually ends
in surrender) or to attack. The warning chance for an armed guard is built up
like this:

| step | chance |
|---|---|
| base | 0.7; 0.8 when this guard is the prisoner's own attacker and has no other target; 0.4 or 0 when another staff member is already fighting the prisoner within 5 or 3 tiles |
| guard more than half dead | × 0.2 |
| prisoner flagged to be fired on at sight (`+0xD38` bit `0x140`, or an escort flag) | 0 |
| guard pissed off (`Staff+0xA88`, set every tick from the needs vtable slot `0x1B0` while Staff Needs is on) | 0 |
| **Staff Needs on** | **× StaffMorale / 100** (`World+0x2064`, the top-bar figure) |
| the `World+0x2F6E` flag | × 1.5 |

The result is compared with a random number; below it the guard attacks. So
the per-guard state the player expects is there (a guard with neglected needs
fires without warning), but the global morale factor sits on top of it and
scales every armed guard's warning chance by the prison's mood. A prison at 40%
morale gets a warning from a healthy, content armed guard 28% of the time
instead of 70%; a prison at 0% never. Staff deaths pull that figure down
permanently within a session (see `tweaks.md`), which is why armed prisons
drift towards "never warn".

The multiply is the block at `0x1405D7DE5`:

```
1405D7DE5  cmp   byte [r11+0x46E9], 0        ; StaffNeeds option
1405D7DED  jz    1405D7E04                   ; off: skip
1405D7DEF  movss xmm0, [r11+0x2064]          ; StaffMorale
1405D7DF8  mulss xmm0, [0x140B1B1B4]         ; 0.01
1405D7E00  mulss xmm6, xmm0                  ; chance *= morale/100
1405D7E04  cmp   byte [r11+0x2F6E], 0        ; next factor
```

## Fix

One byte: the `jz` at `0x1405D7DED` (`74 15`) becomes `jmp` (`EB 15`). The
multiply is skipped whether or not Staff Needs is on. Nothing else in the
decision changes: the pissed-off test, the fire-on-sight flags, the damage
factor and the base chances are as before, and with Staff Needs off the code
path is identical to the original.

The other reader of the same morale value in guard behaviour, the contraband
search job `FUN_1407A99C0` (a pissed-off guard lets contraband go when morale is
under 40%), is left alone; it is gated on the guard's own state first.

`scripts/Build-ArmedGuardWarnings.ps1` builds the patch and checks the 31 bytes
from the `cmp` to the next factor against the expected instructions.

## Not changed

Issue #1 also reports that prisoners near an armed guard's gunfire no longer
surrender. That is not a scaling problem: the Sunset build has no code that
rolls a surrender for anyone but the prisoner being shot at or shouted at
(every caller of the surrender function, the shot routine, and the unreachable
legacy fire routine were read). Restoring the old "within 4 tiles, at most 10
per shot" rule means new code, not a fix of existing code; it is tracked
separately.

## Verified

Disassembly of a patched copy; patcher `--apply` / `--revert` round trip.
Not yet seen in a running prison: the scenario (an armed guard engaging a
prisoner with Staff Needs on and low morale) has no save-visible outcome the
in-game harness can wait for.
