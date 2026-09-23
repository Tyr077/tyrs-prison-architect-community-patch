# Ranged weapon fire-rate fix: technical notes

Target: `Prison Architect64.exe`, Steam Sunset Update. Same build and conventions
as `gang-handoff.md`. Since 2.0.0 the fix uses the `.tyrs` section
(`code-section.md`).

## Symptom

Assault rifles and submachine guns (RechargeTime 0.1) fire one shot every two
seconds, the same as a sniper rifle. Every ranged weapon waits two seconds after
each shot on top of its `RechargeTime` in `materials.txt`. Community Lua mods
work around it by forcing `ReloadTimer` to zero every tick on guards, which is
expensive and cannot be applied to prisoners without breaking Escape Mode
recruitment.

## Cause

Entity fields: `AttackTimer` at `+0x348`, `ReloadTimer` at `+0x34C`, last
attack time (double, world time) at `+0x310`. Equipment definition:
`RechargeTime` at `+0x50`.

| function | role |
|---|---|
| `FUN_140537930` | FireRangedShot: spends Escape Mode and Warden Mode ammo, spawns the bullet, then stores `ReloadTimer = 2.0f` and `AttackTimer = RechargeTime` |
| `FUN_1405370f0` | NPC ranged attack behaviour: returns while `ReloadTimer > 0`, otherwise counts `AttackTimer` down and fires at zero |
| `FUN_140537ef0` | NPC chase-and-shoot variant, same gate |
| `FUN_140537d00` | counts `ReloadTimer` down; at zero plays the `Reload_` sound and ejects the casing |
| `FUN_140557310` | Escape Mode player attack: returns while `ReloadTimer > 0`, then fires |
| `FUN_140536cb0` | returns the entity's equipment definition |

Because the NPC routine will not count `AttackTimer` while `ReloadTimer` is
positive, every shot costs the reload time plus `RechargeTime`.

### What the 2018 version did

The 2018 version of the game (the Steam beta branch
`prisonarchitect_anniversary_2018_version`) has the same routines with the same
gates. The one difference is the value `FireRangedShot` stores in `ReloadTimer`:

| weapon | 2018 | final build |
|---|---|---|
| AssaultRifle, SubMachineGun | 0.02 s | 2.0 s |
| Tazer | 2.0 s | 2.0 s |
| every other weapon | 0.7 s | 2.0 s |

The final build keeps only the Tazer's value and applies it to everything. (The
three values also survive in the final build's unreachable older firing routine
`FUN_1401AC610`, which is where they were first noticed.) `materials.txt` has
the same `RechargeTime`, `AttackPower`, `Range` and `Ammo` for these weapons in
both versions, so the difference is entirely this one store.

## Fix (2.0.0)

The ten-byte store at `0x140537CC5` (`mov dword [rbx+0x34C], 0x40000000`)
becomes a jump to a stub at `.tyrs+0x920` that stores the 2018 value for the
weapon. `r15` holds the weapon's definition there; its distance from the start
of the definition array (`[0x140DECCC0]`, `0x90` bytes each) identifies it:

```
mov  rax, [0x140DECCC0]
mov  rcx, r15
sub  rcx, rax
mov  eax, 0x40000000          ; 2.0   Tazer 0x25
cmp  rcx, 0x14D0 / je store
mov  eax, 0x3CA3D70A          ; 0.02  AssaultRifle 0x2D, SubMachineGun 0x2E,
cmp  rcx, 0x1950 / je store   ;       ModifiedAssaultRifle 0x68
cmp  rcx, 0x19E0 / je store
cmp  rcx, 0x3A80 / je store
mov  eax, 0x3F333333          ; 0.7   everything else
store:
mov  [rbx+0x34C], eax
jmp  0x140537CCF
```

`rax` and `rcx` are free at that point: the instruction before the hook has just
stored `rax`, and the one after loads `eax`. The ModifiedAssaultRifle is a DLC
weapon the 2018 version does not have; it is an automatic rifle with the same
`RechargeTime` as the AssaultRifle, so it gets the automatic value, as it does in
`weapon-effects.md`.

Nothing else is changed. The NPC routines and the Escape Mode player attack gate
on `ReloadTimer` exactly as they did in 2018, so with the 2018 values they behave
as they did then. Warden Mode gates on `AttackTimer` alone and was never affected.

`scripts/Build-Firerate.ps1` assembles it; `patches/weapon-firerate.patch.json`
is the result.

## Weapon values

From `materials.txt` / `materials_dlc.txt`. Cadence is the reload value plus
`RechargeTime`, for guards and prisoners. Damage per second assumes every shot
hits.

| weapon | RechargeTime | AttackPower | unpatched cadence | fixed cadence (= 2018) | unpatched dmg/s | fixed dmg/s |
|---|---|---|---|---|---|---|
| Gun (revolver) | 0.5 | 15 | 2.5 s | 1.2 s | 6 | 12.5 |
| Shotgun | 1.0 | 25 | 3.0 s | 1.7 s | 8 | 15 |
| Rifle (sniper) | 2.0 | 50 | 4.0 s | 2.7 s | 12 | 18.5 |
| AssaultRifle | 0.1 | 4 | 2.1 s | 0.12 s | 2 | 33 |
| SubMachineGun | 0.1 | 2 | 2.1 s | 0.12 s | 1 | 17 |
| Tazer | 2.0 | 1 | 4.0 s | 4.0 s | | |
| ModifiedHandgun (DLC) | 0.35 | 20 | 2.35 s | 1.05 s | 9 | 19 |
| ModifiedAssaultRifle (DLC) | 0.1 | 5 | 2.1 s | 0.12 s | 2 | 42 |

In Escape Mode the player's gate is `ReloadTimer` alone, so a click fires as soon
as the reload value has run out: 0.7 s for a revolver, every other frame for an
automatic rifle while the button is held.

`Attack_AssaultRifle` and `Attack_SubMachineGun` are multi-round burst samples;
the weapon-effects fix plays them at most every 0.5 s, as the 2018 version did
(`weapon-effects.md`).

## Casings and the reload sound

The reload countdown `FUN_140537d00` is called from the entity update
(`FUN_14053ed20`) only while `ReloadTimer > 0`. When the timer reaches zero it
plays `Reload_<weapon>` (skipped for equipment index 1) and spawns a particle
with `FUN_1403f75b0` (skipped for equipment index 7): the ejected shell casing.
With the 2018 values the casing and the shotgun's pump sound come 0.7 s after
the shot, where the unpatched game has them two seconds after it.

## Earlier versions of this fix

1.0.0 wrote `ReloadTimer = 0`. That skipped the countdown and with it every
casing and the pump sound. 1.1.0 wrote 0.001 instead, which brought them back.
Both removed the wait altogether, so the cadence was `RechargeTime` alone, and
both replaced the Escape Mode gate at `0x140557372` with a stub in the `.text`
cave (`0x140A443C0`) that compared the time since the last shot with
`RechargeTime`, because a gate on a timer that is always zero limits nothing.

With the 2018 version available for comparison it turned out that this made
pistols, shotguns and rifles fire faster than the game ever had them (a revolver
every 0.5 s against 1.2 s). 2.0.0 therefore restores the 2018 values instead,
gives the Escape Mode gate its original bytes back and clears the old stub out
of the cave.

For upgrades, the patch file keeps edits for the two sites 2.0.0 no longer
changes, with `replace` equal to the original bytes, and every edit lists the
bytes 1.1.0 and 1.0.0 left at its site as `superseded`. The patcher then reads
an exe patched by any earlier release as "installed (older version)" and
rewrites it on Apply; Revert works from either layout. 1.0.0 predates the
`.tyrs` section, so the patcher treats an edit inside a missing section as still
holding its original bytes.

## Verified

Disassembly of a patched copy (`DumpAsmRange` of the hook, the stub and the
restored gate). Patcher round trips on scratch copies: fresh install; upgrade
from the 1.0.0, 1.5.0 and 1.10.0-test1 patchers, with and without tweaks, to the
same hashes as a fresh install; revert from every one of those to the original
hash. Not yet confirmed in a running prison.
