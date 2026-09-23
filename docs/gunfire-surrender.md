# Prisoners near gunfire surrender: technical notes

Target: `Prison Architect64.exe`, Steam Sunset Update. Same build and conventions
as `gang-handoff.md`. Uses the `.tyrs` section (`code-section.md`).

## Symptom

When an armed guard opens fire, only the prisoner being shot at reacts. The
prisoners standing around it carry on as if nothing had happened. Players
remember, and the wiki still says, that "prisoners might surrender if an armed
guard is shooting within 4 squares distance. A maximum of 10 prisoners will
surrender per gun shot." Reported as the second half of GitHub issue #1.

## Cause

That rule was real code. In the 2018 version of the game (the Steam beta branch
`prisonarchitect_anniversary_2018_version`) the routine that fires a shot ends
like this, for every shot fired by anyone but a prisoner, with any weapon but
the Tazer:

```
list = prisoners within 4 tiles of the aim point
     + prisoners within 4 tiles of the shooter
up to 10 times, while the list is not empty:
    take a random prisoner out of the list
    prisoner->OnAttackedBy(shooter)
```

`OnAttackedBy` is the handler a prisoner runs when it is hit. When the attacker
counts as armed (an armed guard with its weapon drawn, a soldier, a sniper
carrying its rifle) it rolls for surrender: certain for a prisoner who is not
misbehaving, less likely for the tough, the fearless and their like. On success
the prisoner surrenders and gets the `surrendered` and `suppressed` status
effects. A prisoner who does not surrender may turn on the shooter. So gunfire
near a crowd made most of it give up, and the hard cases pick a fight.

The final build's `FireRangedShot` (`FUN_140537930`) ends right after it sets
`ReloadTimer` and `AttackTimer`. The block is gone, and nothing else took over
its job: every caller of the surrender function was read, and none of them
looks at prisoners near a shot. The pieces it used are all still there, with
the same signatures as in 2018:

| what | final build |
|---|---|
| objects of one type within a radius | `FUN_1407C1B40(World, int x, int y, float radius, list*, int type, char flag)` |
| entity by id | `FUN_1407BADC0(World, id*)`, 0 when the id is stale |
| `OnAttackedBy` | Prisoner vtable `+0x190` (`FUN_1406C4390`), called from `TakeDamage` |
| the list | `{ id pairs*, int capacity, int count }`, zeroed by the caller, grown by the range function, freed by the caller with `FUN_1408252F0` |
| random number | generator object at `0x140D2CA58`, `[vtable+0x10]` |

## Fix

The last two instructions before the epilogue, at `0x140537CCF`
(`mov eax,[r15+0x50]` / `mov [rbx+0x348],eax`, AttackTimer = RechargeTime), become
a jump to a stub at `.tyrs+0x970`. The stub runs those two instructions and then
the 2018 block:

```
cmp  dword [rbx+0x40], 0x6D        ; shooter is a prisoner: nothing
je   done
[0x140DECCC0] + 0x25*0x90 == r15   ; Tazer: nothing
je   done
list = {0, 0, 0}                   ; at [rbp-0x29]
FUN_1407C1B40(World, (int)aim.x,     (int)aim.y,     4.0, &list, 0x6D, 1)
FUN_1407C1B40(World, (int)shooter.x, (int)shooter.y, 4.0, &list, 0x6D, 1)
esi = 10
while (list.count > 0 and esi > 0):
    i = random % list.count
    p = FUN_1407BADC0(World, &list.data[i])
    if (p) p->vtable[0x190](p, shooter)
    list.data[i] = list.data[--list.count]
    esi--
if (list.data) free(list.data)
done:
jmp  0x140537CD9                   ; mov al,1 and the epilogue
```

Frame facts the stub relies on: `rbx` is the shooter and `r15` the weapon's
definition; `rsp` is 16-byte aligned with the function's `0xC0` bytes of frame
below `rbp+0x37` (`rbp = rsp+0x89`), so the fifth to seventh arguments go to
`[rsp+0x20..0x37]`; the aim point is the function's second argument, at its home
`[rbp+0x77]` / `[rbp+0x7B]`; `rsi`, `rdi` and `r14` were pushed by the prologue
and are popped right after the hook, so the stub uses them across its calls. The
list sits in the function's string locals at `[rbp-0x29]`, which are finished
with by then and clear of the argument slots.

It is the 2018 block instruction for instruction in what it does, with one
difference: 2018 called through the resolved prisoner without testing it, and
the stub skips an id that no longer resolves. As in 2018, the prisoner being
shot at is usually in the list too, a prisoner standing near both the shooter
and the aim point is in it twice, and there is no cooldown: an automatic weapon
rolls for up to ten prisoners on every round.

Shots in Escape Mode and Warden Mode go through the same routine, as they did in
2018. Your own gang's shots are a prisoner's and do nothing here; the warden's
are not an armed attacker's in `OnAttackedBy`, so they do not make anyone
surrender, though a bystander may turn on the warden.

`scripts/Build-GunfireSurrender.ps1` assembles it;
`patches/gunfire-surrender.patch.json` is the result. It is independent of the
fire-rate fix, which hooks the ten bytes before it.

## Related

The other half of issue #1, armed guards warning less often at low staff morale,
turned out to be how the game has always worked (the 2018 version has the same
multiply). That one is an optional tweak: `tweaks.md`.

## Verified

Disassembly of a patched copy; patcher `--apply` / `--revert` round trip.
Not yet confirmed in a running prison.
