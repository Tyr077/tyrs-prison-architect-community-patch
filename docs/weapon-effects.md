# Weapon effects fix: technical notes

Target: `Prison Architect64.exe`, Steam Sunset Update. Same build and conventions
as `gang-handoff.md`. Needs the code section (`code-section.md`).

## Symptom

Guns fire without their visual effects: no muzzle flash on assault rifles and
SMGs, and no smoke or spread of buckshot from the shotgun. Every shot draws a
single thin tracer. Automatic rifles also play a full burst sample for every
round.

## Cause

The game contains two weapon-fire routines.

`FUN_1401AC610` is the older one. It is reached only through script command
`0x3B` in the command dispatcher `FUN_1401ADAB0`, and nothing queues that command
any more. For a ranged weapon it:

- plays `Attack_<weapon>`; for the AssaultRifle and SubMachineGun only when the
  last one played at least 0.5 s ago, keeping the time in `Entity+0x340` (their
  sounds are multi-round burst samples);
- for the Shotgun, spawns five smoke puffs (`FUN_1403F6C70`) towards random
  points on a disc of radius `distance * 0.1` around the target, then fifteen
  tracers (`FUN_1403F6990`) to random points on the same disc;
- for the AssaultRifle and SubMachineGun, spawns a muzzle flash
  (`FUN_1403F7130`) at the shooter along its facing, and one tracer;
- for other guns, one tracer; for the Tazer, the spark `FUN_1403F7F60`.

Weapons are recognised by name against the equipment name table: Shotgun
(`0x20`), Tazer (`0x25`), AssaultRifle (`0x2D`), SubMachineGun (`0x2E`).

`FireRangedShot` (`FUN_140537930`) is the routine every shooter now uses: NPC
attacks (`FUN_140537300`), snipers (`FUN_140723800`), Warden Mode
(`FUN_140764010`) and Escape Mode (`FUN_140557310`). It plays `Attack_` on every
shot, spawns one tracer and nothing else. The tazer spark survived in
`FUN_140537300`; the other effects did not.

## Fix

Two hooks in `FireRangedShot`. At both, `rbx` = shooter, `r15` = the weapon's
`EquipmentDef`, `rbp` = frame base and `rsp % 16 == 0`. `rsi`, `rdi` and `r14`
are saved by the prologue and not read again after the hooks, so the stubs use
them; `xmm6` and up and `r12`/`r13` are not touched. Weapons are identified by
`r15 - [0x140DECCC0]` (the `EquipmentDef` array, `0x90` stride): `0x1200`
Shotgun, `0x1950` AssaultRifle, `0x19E0` SubMachineGun, and `0x3A80`
ModifiedAssaultRifle, the DLC automatic rifle added after the old routine was
written.

1. `0x140537C80` (`lea rcx,[rbx+0x48]` / `call` tracer, 9 bytes) jumps to the
   effects stub at `.tyrs+0x530`. It spawns the tracer and adds it to the
   particle system (`FUN_1403F1DF0(World+0xDE8, p, 1)`) as before, then:
   - automatic rifles: a muzzle flash at `[rbx+0x48]` along `[rbx+0x54]`;
   - Shotgun: radius = `|aim - shooter| * 0.1`; nineteen times, a random angle
     (`[0x140D2CA58]` vtable `+0x10` over `[0x140D2CA60]`, times 2π) rotates
     `(1,0,0)` about `(0,0,1)` with `FUN_14011FF20`, the result is scaled to the
     radius and added to the aim point `[rbp+0x67]`; the first five iterations
     spawn smoke towards that point, the other fourteen a tracer, which with the
     original makes fifteen.
   It resumes at `0x140537CA9`. Scratch vectors use the function's string locals
   at `[rbp-0x59]`, `[rbp-0x49]`, `[rbp-0x29]` and `[rbp-0x19]`, which are
   finished with by then.
2. `0x140537B32` (`mov r8,r15` / `lea rdx,"Attack_"`, 10 bytes) jumps to the
   sound stub at `.tyrs+0x710`. For the automatic rifles it reads the clock
   (`FUN_14011D620`, double seconds); if less than 0.5 s has passed since
   `[rbx+0x340]` it jumps to `0x140537C68`, past the sound block, otherwise it
   stores the time. Every other path replays the two instructions and resumes at
   `0x140537B3C`. `Entity+0x340` is zeroed by the Entity constructor and read or
   written by nothing but the old routine.

Only effects and the sound spacing change. Damage, hit chance, ReloadTimer and
AttackTimer are untouched, so the fire-rate fix is unaffected.

`scripts/Build-WeaponEffects.ps1` assembles both stubs; `-FxAt` and `-SndAt`
move them.

## Verified

Disassembly of a patched copy (all seventeen fixes): both hooks, both stubs,
their rip-relative constants (0.1f at `.tyrs+0x6FE`, 2π at `+0x702`, 0.5 at
`+0x77B`) and every jump back into the function. Not yet seen in a running
prison.

## Not changed

The old routine also used different reload timers (0.02 s for the automatic
rifles, 0.7 s for other guns, 2 s for the tazer). Those belong to the fire-rate
question and are described in `weapon-firerate.md`; this fix leaves them alone.
