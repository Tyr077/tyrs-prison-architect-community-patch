# Scripted status effects (Lua `StatusEffects` table): technical notes

Target: `Prison Architect64.exe`, Steam Sunset Update. Same build and conventions
as `gang-handoff.md`; the code section is described in `code-section.md`.

## Symptom

Alpha 28 added direct property access for scripted objects and, with it,
`this.StatusEffects.<name> = value` for prisoners. Mods such as Less Lethal
Expansion (workshop 2787997082) use it from a guard's script:

```lua
prisoner.StatusEffects.tazed = 60
prisoner.StatusEffects.sedated = 60
prisoner.StatusEffects.surrendered = 40
```

On the Sunset build the assignment is silently ignored. Reading the value back
(`prisoner.StatusEffects.tazed`) returns what was written, but the prisoner is
never tazed, sedated or suppressed, the status icon never appears, and the
value is not in the save file. Modders reported it as "the StatusEffects thing
no longer works".

## How the table is built

`Prisoner::RegisterLua` (`FUN_1406c68d0`) calls
`StatusEffectSystem::RegisterLua` (`FUN_14072d040`) with the prisoner's system
(`Prisoner+0x3C8`). That function creates the `StatusEffects` table, stores the
system pointer in it as light userdata under the key `Manager`, and for each of
the 27 named effects registers a C getter (`FUN_14072da00`) and setter
(`FUN_14072dc60`) in `GetterTable` / `SetterTable`. The shared metatable code
(`FUN_14045b0e0`) then compiles the usual `__index` / `__newindex` Lua
functions that route reads and writes to those tables. `Needs` is built the same
way (`FUN_140624da0`) and works.

The effect names (static table `DAT_140dfbce0`, 28 entries of 0x30 bytes:
`std::string name`, add multiplier, decay rate, maximum) are, in slot order:
`none`, `suppressed`, `goodfood`, `drunk`, `high`, `withdrawal`,
`tazed`, `overdosed`, `surrendered`, `calming`, `angst`, `wounded`, `virus`,
`virusdeadly`, `overheating`, `exposure`, `foodpoisoning`, `riledup`,
`sedated`, `StatusSwimming`, `StatusDrowning`, `Healthy`, `StatusSmelly`,
`calamitycold`, `heatstroke`, `calamityflu`, `infected`,
`StatusRunningInFear`. Lookup from Lua (`FUN_14072c260`) is a `_stricmp`, so
the key is case-insensitive.

## The system

`StatusEffectSystem` is 0x630 bytes: 28 slots of 0x38 bytes from `+0x000`,
then an "active" bitset at `+0x620` (28 bits in a `uint32`) with a `uint64`
copy at `+0x628` that is what the save file carries (registered as `has` in
the DataRegistry by `FUN_14072cc70`). A slot is:

| offset | field |
|---|---|
| `+0x00` | `Charge` (float, the value Lua reads and writes) |
| `+0x04` | `LastCharge` |
| `+0x08` | `std::string` `status_effect_<name>` (language key) |
| `+0x28` | double: world clock when the effect was last applied |
| `+0x30` | bool: applied in the last half minute (`FUN_14072dec0`) |
| `+0x34` | int: displayed charge |

Everything that acts on an effect goes by the bitset, not the charge:

- `Update` (`FUN_14072c5f0`) decays only slots whose bit is set, clears the bit
  when the charge drops below zero, and copies `+0x620` to `+0x628`.
- `IsActive` (`FUN_14072c7a0`) is a bit test. It has ten callers, among them
  the nameplate/status icons (`FUN_140437810`) and the AI checks.
- The save writer (`FUN_14072cf90`) writes only slots whose bit is set; the
  loader (`FUN_14072cea0`) sets the bit for each slot it reads with a positive
  charge.
- The game's own `Add` (`FUN_14072c7f0`, charge += amount * multiplier,
  clamped to the maximum) and `Set` (`FUN_14072c930`, charge = fraction *
  maximum) both stamp `+0x28` with the world clock (`World+0x80`) and set the
  bit.

The bitset is the newer part: its accessors carry the MSVC
`"invalid bitset<N> position"` check, and the pre-bitset design that Alpha 28
documented simply looked at the charge.

## Where it goes wrong

The Lua setter validates its arguments, fetches `Manager`, resolves the key to
a slot index and then does only this (`0x14072DE0D`):

```
14072de0d  48 98              cdqe                    ; rax = index
14072de0f  48 6B C8 38        imul rcx,rax,0x38
14072de13  F3 0F 11 34 39     movss [rcx+rdi],xmm6    ; slot.Charge = value
14072de18  ...                (destroy the key string, return 0)
```

No timestamp, no bit. The charge sits in a slot that `Update`, `IsActive` and
the save writer never look at. The getter (`FUN_14072da00`) reads the charge
directly, which is why the value appears to stick from Lua's point of view.

## Fix

The 11 bytes at `0x14072DE0D` become a `jmp` to a 90-byte stub at
`.tyrs+0x170` (`0x140E89170`), padded with a 6-byte NOP. The stub does what
`Set` does, plus the mirror copy, and returns to `0x14072DE18`:

```
cdqe
imul  r8,rax,0x38
add   r8,rdi                  ; r8 = slot
movss [r8],xmm6               ; slot.Charge = value        (the original store)
mov   rdx,[rip+App]           ; App = 0x140D57900
mov   rdx,[rdx+0x198]         ; World
mov   rdx,[rdx+0x80]          ; world clock
mov   [r8+0x28],rdx           ; slot.LastApplied = now
mov   ecx,eax
mov   edx,1
shl   edx,cl                  ; bit for this effect
xorps xmm0,xmm0
comiss xmm6,xmm0
ja    set
not   edx
and   [rdi+0x620],edx         ; value <= 0 (or NaN): clear
jmp   mirror
set:  or [rdi+0x620],edx      ; value > 0: activate
mirror:
mov   edx,[rdi+0x620]
mov   [rdi+0x628],rdx         ; zero-extended copy for the save file
jmp   0x14072DE18
```

At the hook `eax` is the effect index (already checked >= 0), `rdi` the
system, `xmm6` the value as a float; `rcx`, `rdx`, `r8`, `xmm0` and the flags
are free (the return point starts with a `cmp` and reloads all three
registers before use).

Behaviour after the fix:

- `prisoner.StatusEffects.tazed = 60` activates the effect: the icon appears,
  the AI reacts, it decays at the effect's normal rate and is written to the
  save.
- Assigning `0` (or a negative number) deactivates the effect at once. Without
  this, an effect whose decay rate is zero would stay "active" with an empty
  charge.
- The value is stored as given, not clamped to the effect's maximum; that is
  what Alpha 28 did and what mods were written against. The maxima are
  `tazed` 60, `sedated` 60, `surrendered` 30, `suppressed` 1440.
- The getter is unchanged.
- The mirror copy is updated immediately so a `FUN_14072c720` refresh (which
  rebuilds `+0x620` from `+0x628`) between the assignment and the next update
  cannot lose the bit.

`scripts/Build-LuaStatusEffects.ps1` generates the patch;
`patches/lua-status-effects.patch.json` is the result. It requires the hidden
`code-section` base patch. Verified by disassembling a patched copy.

## Testing

`tools/testmods/lua-status-effects-test/` is a tiny local mod: a placeable
"Status Effect Tester" object (Objects menu, Security filter) whose script sets
`tazed = 60` on every prisoner within five tiles every few seconds. Copy the
folder to `%LocalAppData%\Introversion\Prison Architect\mods\` and enable it
under Extras > Mods. Unpatched, prisoners walk past it; patched, they drop as
if tazed and show the icon. Less Lethal Expansion is the real-world case.

## Not covered

The Needs setter (`FUN_140625a00`) writes the need's value directly as well,
but the needs system has no equivalent active flag, so it is unaffected.
Status effects on non-prisoner entities are not exposed to Lua by the game.
