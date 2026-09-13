# Pavilion reload fix: technical notes

Target: `Prison Architect64.exe`, Steam Sunset Update. Same build and conventions
as `gang-handoff.md`. Needs the code section (`code-section.md`).

## Symptom

An armed guard manning a Guard Pavilion fires once and never again. Guards and
modded guards with ranged weapons are affected the same way.

## Cause

A guard on a pavilion is carried by it: `Entity+0x6E` (`Loaded`) is set and its
`CarrierId` is the pavilion. The entity update `FUN_14053ED20` first calls
`FUN_14053BED0`, which returns 1 for any loaded entity, and the update returns
immediately. The reload countdown `FUN_140537D00`, which runs later in the same
update while `ReloadTimer` (`+0x34C`) is positive, is never reached.

Every shot sets `ReloadTimer` (2.0 s in the shipped game, 0.001 s with the
fire-rate fix), and the NPC attack routines (`FUN_1405370F0`, `FUN_140537EF0`)
do nothing while it is positive. A stationed guard's timer never runs down, so
after its first shot it can never shoot again. The All-in-One mod's pavilion
script works around it by decrementing `ReloadTimer` for the stationed guard
once a second.

## Fix

`0x14053BEE1`, the first instruction of `FUN_14053BED0`'s loaded branch
(`movsxd rax,[rcx+0x40]` / `test eax,eax`, 6 bytes), jumps to a stub at
`.tyrs+0x790`:

```
xorps  xmm0,xmm0
comiss xmm0,[rcx+0x34C]      ; ReloadTimer > 0 ?
jae    resume
sub    rsp,0x30              ; rsp % 16 was 0 (sub rsp,0x28 on entry)
mov    [rsp+0x20],rcx
movss  [rsp+0x28],xmm2       ; frame time, copied from xmm1 at 0x14053BED8
movaps xmm1,xmm2
call   0x140537D00           ; reload countdown (entity, dt)
mov    rcx,[rsp+0x20]
movss  xmm2,[rsp+0x28]
add    rsp,0x30
resume:
movsxd rax,[rcx+0x40]        ; replaced instructions
test   eax,eax
jmp    0x14053BEE7
```

`rcx` and `xmm2` are read again after the hook, so they are preserved; the flags
from `test` reach the `js` at `0x14053BEE7` unchanged. Everything else a loaded
entity skips stays skipped.

When the countdown reaches zero it also plays the reload sound and ejects the
shell casing, as it does for any other guard.

`scripts/Build-PavilionReload.ps1` builds the patch; `-StubAt` moves the stub.

## Verified

Disassembly of a patched copy. Not yet seen in a running prison.

## Not changed

The All-in-One mod's pavilion script also fixes guards staying in a pavilion
when disarmed, knocked out or killed, two guards claiming one pavilion, and
several engagement choices. Those are separate behaviours and not part of this
fix.
