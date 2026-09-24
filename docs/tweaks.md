# Optional tweaks: technical notes

Target: `Prison Architect64.exe`, Steam Sunset Update. Same build and conventions
as `gang-handoff.md`.

Tweaks change game balance rather than fix bugs. They are off by default in
the patcher and in `--apply`; tick them in the list or pass `--tweaks`.
Each patch file carries `"optional": true`.

## No reoffending fine (`tweak-no-reoffend-fine`)

Every prisoner that leaves gets a record in the Victory system's log
(`VictorySystem` at `World+0x2588`, list at `+0x470`, count at `+0x47C`;
records are the same 0x158-byte object used for escapes and deaths, built by
`FUN_140759570`):

| field | offset |
|---|---|
| type (2 = released, 4 = prisoner death) | `+0x00` |
| `TimeIndex` (world minutes) | `+0x08` |
| prisoner id | `+0x10` |
| `ReoffendingChance` | `+0x30` |
| `ReleaseStatus` | `+0x34` |
| `TimeOfReoffend` / `TimeOfReturn` / `TimeOfReform` | `+0x3C` / `+0x40` / `+0x44` |
| stored prisoner data tree | `+0x50` |

`ReleaseStatus` values: 1 WillReform, 2 WillReoffended, 3 Reformed,
4 Reoffended, 5 ReoffendedAndReturned. The status is rolled at release
(`FUN_140754110`) from the reoffending chance.

`FUN_140753a40` runs over the log. Two days after release a WillReoffended
record becomes Reoffended, the finance system is charged
`FUN_1405a0470(finance, -5000, "parole_fine", ...)`, and the running fines
total at `World+0x860` drops by 5000. (WillReform becomes Reformed with a
+1000 `reform_reward`.) Both branches are gated on the Second Chances DLC
being present in the list at `App+0xEB0+0x510`.

Edits: the `call` at `0x140753C0B` and the `subss xmm0, xmm8` at
`0x140753C5C` become 5-byte NOPs. The status still changes, so reoffenders are
still counted and can still return; only the money is untouched.

## No returning prisoners (`tweak-no-returning-prisoners`)

When intake creates a prisoner, `FUN_1406a8920` (called from prisoner
generation `FUN_1406a8360`) scans the log for a record with
`ReleaseStatus == 4`, requires the death-row flag of the record and the new
prisoner to agree, and takes it with a 40% chance keyed on the record id
(`id % 100 < 40`). It then deserialises the stored data tree at record `+0x50`
into the new prisoner: same name, traits, reputations, work experience. The
record moves to status 5 and `TimeOfReturn` is stamped. Otherwise it falls
through to normal generation (`FUN_1404943a0`) for the requested category.

Because the returning prisoner is a copy of the one who left, it keeps every
reputation it earned in the prison, which is how a Min Sec with extreme traits
walks in.

Edit: `cmp dword [rsi+0x34], 4` at `0x1406A89E8` becomes `cmp ..., 0x7F`, a
value the status never holds. The scan never matches and every intake prisoner
is freshly generated. Records still reach status 4, so statistics and the fine
are unchanged.

A softer variant (keep the returnee but re-roll its reputations by the
category rules) is possible later; it needs the trait generator, not just a
compare.

## Staff death morale penalty fades (`tweak-staff-death-morale-decay`)

`Thermometer` (registry ctor `FUN_14073bb70`) holds staff morale at `+0x3C`,
the desired value at `+0x40` and the rate at `+0x44`.
`FUN_14073e580` recomputes the desired value:

```
desired = 100
        + happy   / staffCount * 50
        - unhappy / staffCount * 100
        - injured / staffCount * 50
        - staffDeaths                     ; int at World+0x2798
        + (payFactor - 1) * 100           ; World+0x838
```

`World+0x2798` is `VictorySystem+0x210`, incremented in `FUN_1407551e0` for
any dying entity whose type has the staff flag (the staff branch only bumps
the counter; prisoner deaths take a different branch that bumps
`VictorySystem+0xF8` and appends a type-4 record to the log). An exhaustive
scan of every instruction touching the field (`DumpDispSites 0x2798`, plus
`+0x210` inside the Victory code) finds exactly two readers: this formula and
the top-bar staff morale tooltip in `FUN_14039bc00`
(`interfacetopbar_staffmorale_staffdeaths`). It is not registered with the
data registry, so it is per session, not per save. It has nothing to do with
the death log, the "too many deaths" failure condition or gravestones (those
are Undead-DLC zombie spawners with their own timers).

Edit: the 15 bytes at `0x14073E633`
(`movd xmm0,[rdx+0x2798]; cvtdq2ps xmm0,xmm0; subss xmm3,xmm0`) become a jump
to a stub in the `.tyrs` section (see `code-section.md`) that returns to
`0x14073E642`. Free at that point: `rax`, `r8`, `r9`, `xmm0`, flags. `rdx` is
the World, `xmm3` the running desired morale.

The stub never writes the game's counter. It keeps its own `forgiven` count
in the section and subtracts `deaths - forgiven` instead:

```
mov   eax, [rdx+0x2798]      ; deaths
mov   r9d, [forgiven]
cmp   r9d, eax
jle   day
xor   r9d, r9d               ; forgiven > deaths: a fresh world, reset
mov   [forgiven], r9d
day:
movsd xmm0, [rdx+0x80]       ; world time in minutes
divsd xmm0, [K1440]          ; days
cvttsd2si r8d, xmm0          ; day number
dec   r8d
cmp   r8d, [lastDay]         ; ZF: exactly one day since the last tick
lea   r8d, [r8+1]            ; flags kept
mov   [lastDay], r8d         ; always track the day
jne   apply                  ; same day, first tick, or a jump of days
cmp   r9d, eax
jge   apply                  ; nothing left to forgive
inc   r9d                    ; one death forgiven per day
mov   [forgiven], r9d
apply:
sub   eax, r9d
cvtsi2ss xmm0, eax
subss xmm3, xmm0
jmp   0x14073E642
```

`lastDay` lives at section `+0x000` and `forgiven` at `+0x004`, both starting
at 0; `K1440` is a double at `+0x008`. Decay only happens on a day change of
exactly one, so the first tick after a load, or a different save loaded in the
same process, records the day without forgiving anything. The rate is one
death per in-game day. Because the counter is untouched, the top-bar line
keeps showing the real number of deaths while the morale penalty fades.
`scripts/Build-MoraleDecay.ps1` assembles it; the patch declares
`"requires": ["code-section"]`.

Version 1.0.0 of this tweak wrote a shorter stub that decremented the game's
counter. Those bytes are kept in the patch as the stub edit's `superseded`
entry, padded to the current length with the section's `0xCC` fill, so a game
file patched by an earlier release reads as outdated rather than unknown and is
rewritten in place. Without it the whole file is rejected as an unsupported
build, and even Revert stops working.

## Armed guard warnings ignore overall staff morale (`tweak-armed-guard-warnings`)

With Staff Needs enabled, armed guards shout a warning before opening fire less
often the lower the prison's overall staff morale is; at 0% they never warn,
whatever the state of the guard itself. Reported as GitHub issue #1 and shipped
as a fix in the 1.10.0 test build. The 2018 version of the game has the same
multiply in the same place, and the wiki documents it ("Overall staff morale
also affects this behaviour"), so it is how the game was designed and not
something a later update broke. It is therefore a tweak. The byte is the same as
the test build's, so an exe patched by that build shows the tweak as installed.

A guard's combat step, `FUN_1405D7680`, decides once per engagement whether to
shout (`FUN_1405DC370`, which calls the prisoner's OnWarnedBy and usually ends
in surrender) or to attack. The warning chance for an armed guard:

| step | chance |
|---|---|
| base | 0.7; 0.8 when this guard is the prisoner's own attacker and has no other target; 0.4 or 0 when another staff member is already fighting the prisoner within 5 or 3 tiles |
| guard more than half dead | x 0.2 |
| prisoner flagged to be fired on at sight (`+0xD38` bit `0x140`, or an escort flag) | 0 |
| guard pissed off (`Staff+0xA88`, set every tick from the needs vtable slot `0x1B0` while Staff Needs is on) | 0 |
| **Staff Needs on** | **x StaffMorale / 100** (`World+0x2064`, the top-bar figure) |
| the `World+0x2F6E` flag | x 1.5 |

The result is compared with a random number; below it the guard attacks. A
prison at 40% morale gets a warning from a healthy, content armed guard 28% of
the time instead of 70%. Staff deaths pull the figure down for the rest of the
session (see the morale tweak above), which is why armed prisons drift towards
"never warn".

```
1405D7DE5  cmp   byte [r11+0x46E9], 0        ; StaffNeeds option
1405D7DED  jz    1405D7E04                   ; off: skip
1405D7DEF  movss xmm0, [r11+0x2064]          ; StaffMorale
1405D7DF8  mulss xmm0, [0x140B1B1B4]         ; 0.01
1405D7E00  mulss xmm6, xmm0                  ; chance *= morale/100
1405D7E04  cmp   byte [r11+0x2F6E], 0        ; next factor
```

Edit: one byte. The `jz` at `0x1405D7DED` (`74 15`) becomes `jmp` (`EB 15`), so
the multiply is skipped whether or not Staff Needs is on. The pissed-off test,
the fire-on-sight flags, the damage factor and the base chances are untouched: a
guard whose own needs are neglected still fires without warning, and with Staff
Needs off the code path is identical to the original. The other reader of the
morale value in guard behaviour, the contraband search job `FUN_1407A99C0`, is
left alone.

`scripts/Build-ArmedGuardWarnings.ps1` builds the patch and checks the 31 bytes
from the `cmp` to the next factor against the expected instructions. Verified by
disassembly and the patcher round trip. In the in-game harness
(`tools/ingame-test/tests/armed-guard-warnings.ps1`) a riot at about 14% morale
had 10 prisoners surrendered at the first autosave with the tweak against a peak
of 5 without; that run ended early, so it counts as an indication only.

## Protective Custody prisoners work and attend programs in shared sectors (`tweak-pc-shared-zones`)

Protective Custody prisoners may walk into Shared sectors, and into Custom
sectors whose Protective Custody box is ticked, and spend free time there, but
the final version never gives them a job or a class in those sectors. Only a
sector deployed as Protective Custody Only does. So general population and
Protective Custody cannot share a workshop, kitchen, laundry or classroom, even
with regimes that keep the two groups apart. Switching a prisoner to or from
Protective Custody is enough to stop or start their work and classes. Reported
as GitHub issue #3.

In the 2018 version of the game (the Steam beta branch) Protective Custody
prisoners work and attend programs in Shared sectors, and the final version's
own deployment help says they "will utilise Shared sector rooms" when their
needs are not met in their own sector. The rule may still be meant as a safety
measure, so this ships as a tweak: with it, keeping the groups apart is down to
your deployment and regimes.

Sector zone values, from the name table at `DAT_140DFA070`:

| value | zone |
|---|---|
| 0 | Shared |
| 1-3 | MinSecOnly, MedSecOnly, MaxSecOnly |
| 4 | ProtectedOnly |
| 5-7 | SuperMaxOnly, DeathRowOnly, InsaneSecOnly |
| 8 | StaffOnly |
| 9 | Unlocked |
| 10 | Custom |
| 11 | VisitorOnly |

An entity's zone type comes from `FUN_140536960`: visitors 11, staff 8, and a
prisoner's from its Category through `FUN_14070F370` (Protected → 4). The normal
zone test, `FUN_14070E0D0`, accepts a tile in a Shared or Unlocked sector, in a
Custom sector with the entity's category ticked (flags at sector `+0x1BD`), or in
the "Only" sector matching the zone type. That is how every category is handled.

The final version adds a Protective Custody rule on top, in three places:

1. **Tile check** `FUN_14070E020(sectors, x, y, entity)`. Before the normal zone
   test it refuses zone type 4 whenever the tile's sector is not ProtectedOnly:

   ```
   14070E050  call 0x140536960          ; zone type
   14070E058  cmp eax,4
   14070E05B  jnz 0x14070E076           ; not Protective Custody: normal test
   14070E05D  ...                       ; sector at the tile
   14070E06C  cmp [rax+0x64],r11d       ; ProtectedOnly?
   14070E072  xor al,al                 ; no: refuse
   ```

   The job finder runs every job's tile through this, and so do station
   registration (`FUN_14070E360`), `Entity::TryPassThroughDoor`
   (`FUN_140533FF0`) and a few Escape Mode and prisoner job routines.

2. **Job finder** `FUN_140796DD0` (the function that logs `AssignJob`), prisoner
   block: the sector of the prisoner's work station (`Entity+0x328`, the `.i`
   half of `Station.i`/`Station.u`) must be ProtectedOnly when the Category
   (`+0xA34`) is Protected:

   ```
   140797847  cmp dword [r14+0xA34],4
   14079784F  jnz 0x14079785B
   140797851  cmp dword [rbx+0x64],4
   140797855  jnz 0x140798555           ; refuse the job
   ```

3. **Program and job step** `FUN_140547810`, called by the prisoner's in-class
   handler `FUN_140633350`, the job system (`FUN_140791480`) and `FUN_1405D46E0`.
   A Protected prisoner standing in a sector that is not ProtectedOnly gets 0,
   so a Protective Custody student never sits down in a class held in a Shared
   sector:

   ```
   140547913  cmp dword [rdi+0xA34],4
   14054791A  jnz 0x14054796E
   14054791C  ...                       ; sector at the prisoner's tile
   140547964  cmp dword [rbx+0x64],4
   140547968  jnz 0x14054840E           ; return 0
   ```

The station picker `FUN_14070D5A0` has no such rule, so a Protective Custody
prisoner is given a work station in a Shared sector and then refused every job
there. The 2018 job finder (`FUN_14045FD90` in that build) has no such rule.

Edits: three bytes, one per site, each `jnz` becoming `jmp` so the rule is
skipped:

```
14070E05B  75 19   jnz 0x14070E076   ->   EB 19   jmp 0x14070E076
14079784F  75 0A   jnz 0x14079785B   ->   EB 0A   jmp 0x14079785B
14054791A  75 52   jnz 0x14054796E   ->   EB 52   jmp 0x14054796E
```

Protective Custody is then handled like every other category. The normal zone
test and the sector permission check (`FUN_14070EFE0`) still decide, so a
Protective Custody prisoner works and studies only where its deployment lets it
go: Shared sectors, Custom sectors with Protective Custody ticked, and
Protective Custody Only sectors. Because the tile check is shared, this also
applies to Protective Custody prisoners opening doors themselves, the same way
it already works for other categories.

A separate, older rule affects the statistics but not attendance. During a
Work Lockdown hour, the Experience tick (`FUN_1405889D0`) books a prisoner with
no job and no work station as locked down (`FUN_1406A8C10`), even while it sits
in class. So class time in those hours may show as "locked down" in the
prisoner's record, for any category. The tweak leaves this alone.

`scripts/Build-PCSharedZones.ps1` builds the patch and checks the instructions
around each site. Verified by disassembly and the patcher round trip, and in the
game with `tools/ingame-test/tests/pc-shared-zones.ps1` on the demo save attached
to issue #3, in which every sector apart from staff areas is Shared. The test's
`pc-test` mod switches prisoners to Protective Custody in the running game with
`Object.SetProperty(prisoner, "Category", 4)`, the call security-level changer
mods use; it can also spawn new prisoners, and it counts prisoners with a work
station and a job by category. Each run compares the build with and without the
tweak.

Switched at load (the save's 228 SuperMax prisoners), two game hours of work and
morning classes:

| build | PC holding a job | PC Work minutes | PC in class (two autosaves) | PC Class minutes |
|---|---|---|---|---|
| without the tweak | 0 (with 45-54 holding a station) | 0 | 0 | 17 |
| with the tweak | 47-52 | 3,291 (71 prisoners) | 102 | 1,083 (49 prisoners) |

Without the third edit, the same 51 students of the 09:00 sessions sat in class
50/51 while SuperMax and 0/51 once switched to Protective Custody.

Switched mid-shift, reproducing the report (measured with the first two edits):
60 working MinSec prisoners made Protective Custody at about 09:38, measured
from 09:21 to 11:51:

| build | toggled prisoners holding a job afterwards | their Work minutes |
|---|---|---|
| without the tweak | 1 / 1 / 1 | 372 (almost all before the switch) |
| with the tweak | 12 / 10 / 14 | 1,877 |

MinSec prisoners worked in every run. They took fewer jobs with the tweak because
the two groups now share the same job slots. SuperMax prisoners in Shared
sectors work in both builds, so the rule is specific to Protective Custody.
