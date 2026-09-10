# Ranged weapon fire-rate fix: technical notes

Target: `Prison Architect64.exe`, Steam Sunset Update. Same build and conventions
as `gang-handoff.md`.

## Symptom

Assault rifles and submachine guns (RechargeTime 0.1) fire one shot every two
seconds, the same as a sniper rifle. Every ranged weapon is capped at one shot
per two seconds regardless of its `RechargeTime` in `materials.txt`. Community
Lua mods work around it by forcing `ReloadTimer` to zero every tick on guards,
which is expensive and cannot be applied to prisoners without breaking Escape
Mode recruitment.

## Cause

Entity fields: `AttackTimer` at `+0x348`, `ReloadTimer` at `+0x34C`, last
attack time (double, world time) at `+0x310`. Equipment definition:
`RechargeTime` at `+0x50`.

| function | role |
|---|---|
| `FUN_140537930` | FireRangedShot: spends escape-mode ammo, spawns the bullet, then stores `ReloadTimer = 2.0f` and `AttackTimer = RechargeTime` |
| `FUN_1405370f0` | NPC ranged attack behaviour: returns while `ReloadTimer > 0`, otherwise counts `AttackTimer` down and fires at zero |
| `FUN_140537ef0` | NPC chase-and-shoot variant, same gate |
| `FUN_140537d00` | counts `ReloadTimer` down, plays the `Reload_` sound at zero |
| `FUN_140557310` | Escape Mode player attack: returns while `ReloadTimer > 0`, then fires |
| `FUN_140536cb0` | returns the entity's equipment definition |

Because the NPC routine will not count `AttackTimer` while `ReloadTimer` is
positive, every shot costs 2.0 s plus `RechargeTime`. The author of the
Weapon Firerate Fix mod notes the old 2.7 build had no `ReloadTimer` field at
all, so the pre-Double-Eleven cadence was `RechargeTime` alone.

## Fix

1. `0x140537CC5`: `mov dword [rbx+0x34C], 0x40000000` becomes
   `mov dword [rbx+0x34C], 0`. NPC cadence is now `AttackTimer = RechargeTime`.
   The reload sound path never triggers, matching the old build.
2. The Escape Mode player attack gated only on `ReloadTimer`, so it would now
   fire without limit. The 16-byte gate at `0x140557372`
   (`xorps xmm0,xmm0; comiss xmm0,[rbx+0x34C]; jc ret`) is replaced by a jump to
   a stub that compares the time since the last shot with `RechargeTime`:

```
mov rcx, rbx                      ; entity
lea rdx, [rsp+0x40]               ; scratch out-param (caller home space)
call FUN_140536cb0                ; rax = equipment definition
cvtss2sd xmm1, dword [rax+0x50]   ; RechargeTime
mov rax, [0x140D57900]
mov rax, [rax+0x198]              ; World
movsd xmm0, [rax+0x80]            ; world time
subsd xmm0, [rbx+0x310]           ; minus last shot time
comisd xmm0, xmm1
jb   0x140557422                  ; too soon: return
jmp  0x140557382                  ; continue the attack
```

The stub lives at `0x140A443C0`, the last 64 bytes of the `.text` slack after
the hand-off fix. Later fixes need a different cave.

`scripts/Build-Firerate.ps1` assembles it; `patches/weapon-firerate.patch.json`
is the result.

## Balance note

With the fix, weapons fire at the `RechargeTime` values in `materials.txt`:
revolver 0.5 s, shotgun 1.0 s, sniper rifle 2.0 s, assault rifle and SMG
0.1 s. Those are the shipped values and were the effective rates before the
Sunset Update. Mods that lower `RechargeTime` now have the effect their authors
intended.
