# Disarmed armed guards fix: technical notes

Target: `Prison Architect64.exe`, Steam Sunset Update. Same build and conventions
as `gang-handoff.md`. Needs the code section (`code-section.md`).

## Symptom

An armed guard who has been disarmed can no longer fight while Freefire is on,
or once it has taken more than 70% damage. It keeps engaging prisoners but never
does any damage, and stays locked in the fight.

## Cause

`GetEquipmentDef` (`FUN_140536CB0`) chooses the weapon an entity fights with.
Equipment ids index the `EquipmentDef` array (`[0x140DECCC0]`, `0x90` stride):
0 None, 1 Fists, `0x20` Shotgun and so on.

For an ArmedGuard (type `0x6B`) it calls `FUN_1405D6A80`, "is the weapon drawn":
type `0x6B` and `WeaponDrawn` (`Entity+0xBFC`) above zero. The armed guard's
update `FUN_1404882B0` sets that timer to 5 s while Freefire applies to it
(the global flag, or its sector's flag with per-sector actions) and it has a
target; its damage handler `FUN_140488500` sets it when it is attacked at 60% or
more damage. If the weapon is drawn, `GetEquipmentDef` returns the definition of
the item the guard carries (`+0x2F8`); if not, Fists.

It never checks that the guard still carries something. A disarmed armed guard
carries item 0, None, which has no attack power and is not a ranged weapon. The
attack code then takes the melee path and deals nothing.

## Fix

`0x140536DF3` (`mov rcx,rdi` / `call FUN_1405D6A80`, 8 bytes) becomes a `call`
to a stub at `.tyrs+0x7D0` plus three `nop`s; the stub returns to the
`test al,al` at `0x140536DFB`:

```
mov  rcx,rdi
cmp  dword [rdi+0x2F8],0     ; carries nothing?
jne  0x1405D6A80             ; no: the original predicate (tail call)
xor  al,al                   ; yes: not drawn, so Fists
ret
```

Only this call site changes. `FUN_1405D6A80` itself, and its other callers (the
prisoner surrender checks, the weapon-drawing animation, the tazer choice), are
untouched. An armed guard with a weapon behaves exactly as before.

`scripts/Build-DisarmedArmedGuards.ps1` builds the patch; `-StubAt` moves the
stub.

## Verified

Disassembly of a patched copy. Not yet seen in a running prison.

## Not changed

Getting the shotgun back is a separate question: the game does not send
disarmed armed guards to rearm. The All-in-One mod handles that for guards'
stun batons from its Weapon Rack script.
