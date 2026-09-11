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

1. `0x140537CC5`: `mov dword [rbx+0x34C], 0x40000000` (2.0 s) becomes
   `mov dword [rbx+0x34C], 0x3A83126F` (0.001 s). The reload timer now
   expires on the next entity update, so the NPC routine starts counting
   `AttackTimer` at once and the cadence is `RechargeTime` plus at most one
   tick. Version 1.0.0 of this fix wrote 0.0 here; see "Casings" below for why
   that was wrong and why 1.1.0 uses a small positive value instead.
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
the hand-off fix. Later fixes use the `.tyrs` section instead.

`scripts/Build-Firerate.ps1` assembles it; `patches/weapon-firerate.patch.json`
is the result. The edit at `0x140537CC5` lists the 1.0.0 bytes as
`superseded`, so a game file patched by 1.0.0 through 1.4.1 is recognised and
rewritten on upgrade.

## Casings and the reload sound (why 1.0.0 was wrong)

The reload countdown `FUN_140537d00` is called from the entity update
(`FUN_14053ed20`) only while `ReloadTimer > 0`. When the timer reaches zero it
does two more things besides clearing it: it plays `Reload_<weapon>` (skipped
for equipment index 1, the baton) and it spawns a particle with
`FUN_1403f75b0` (skipped for equipment index 7): a small sprite thrown sideways
from the entity's facing at 3 to 7 tiles per second with random spin and
gravity of 600. That particle is the ejected shell casing. With `ReloadTimer`
written as 0.0 the countdown never ran, so 1.0.0 lost every casing and the
shotgun pump sound (`Reload_Shotgun`, the only `Reload_` event in
`sounds.txt`). It was reported that the casings were missing; a Lua workaround
that writes 0.01 instead of 0 brought them back, which is the same mechanism.

With 0.001 the countdown runs on the very next update: the casing pops and the
pump sound plays immediately after the shot rather than two seconds later.
The countdown does not gate anything else, so the only cost is the one tick
the NPC routine waits before it starts `AttackTimer`.

## What the game actually does per shot (Sunset build)

`FireRangedShot` (`FUN_140537930`), for any shooter:

1. In Escape Mode only, and only for the player's gang: take one round from
   the shooter's magazine for the current weapon; if it is empty, play
   `OutOfAmmo` and do not fire. `Ammo` in `materials.txt` is that magazine
   size. Nothing reads it for guards, snipers, soldiers or ordinary prisoners:
   NPCs have unlimited ammunition and never stop to reload a magazine.
2. Play `Attack_<weapon>`, spawn the bullet, record the shot time at
   `Entity+0x310`.
3. `ReloadTimer = 2.0`, `AttackTimer = RechargeTime`.

The NPC attack routines (`FUN_1405370f0`, `FUN_140537ef0`) do nothing while
`ReloadTimer > 0`, then count `AttackTimer` down and fire when it reaches
zero. So the shipped cadence is `2.0 + RechargeTime` for everybody, with the
casing appearing at the two-second mark. There is no burst or magazine logic
that the timer could be waiting for; it is simply added to every shot.

## Weapon values

From `materials.txt` / `materials_dlc.txt`. "Shipped" is the Sunset build as
released; "fixed" is with this patch. Damage per second assumes every shot
hits.

| weapon | RechargeTime | AttackPower | Ammo (Escape Mode) | shipped cadence | fixed cadence | shipped dmg/s | fixed dmg/s |
|---|---|---|---|---|---|---|---|
| Gun (revolver) | 0.5 | 15 | 6 | 2.5 s | 0.5 s | 6 | 30 |
| Shotgun | 1.0 | 25 | 6 | 3.0 s | 1.0 s | 8 | 25 |
| Rifle (sniper) | 2.0 | 50 | 10 | 4.0 s | 2.0 s | 12 | 25 |
| AssaultRifle | 0.1 | 4 | 30 | 2.1 s | 0.1 s | 2 | 40 |
| SubMachineGun | 0.1 | 2 | 30 | 2.1 s | 0.1 s | 1 | 20 |
| Tazer | 2.0 | 1 | 1 | 4.0 s | 2.0 s | | |
| ModifiedHandgun (DLC) | 0.35 | 20 | 6 | 2.35 s | 0.35 s | 9 | 57 |
| ModifiedAssaultRifle (DLC) | 0.1 | 5 | 30 | 2.1 s | 0.1 s | 2 | 50 |

The assault rifle and SMG are clearly designed as high-rate, low-damage
weapons (4 and 2 damage per round against 15 for a revolver); at the shipped
cadence they were the weakest guns in the game. One thing to be aware of when
judging "too fast": `Attack_AssaultRifle` and `Attack_SubMachineGun` both play
a multi-round burst sample (`gi_m16_burst_*`), so at ten shots per second the
audio is ten overlapping bursts. That is a sound-design mismatch, not a rate
problem; a mod can raise `RechargeTime` on those two weapons if the cadence is
felt to be too high, and with this fix that value is honoured.

## Not verified

Whether the pre-Sunset build had a `ReloadTimer` at all could not be checked;
that binary is not available here. The Weapon Firerate Fix author reports no
such field in 2.7-era save files. What is verified is the shipped code above.
