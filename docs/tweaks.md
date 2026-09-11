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
