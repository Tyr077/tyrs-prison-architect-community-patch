# Weapon effects for mod weapons (modding extension)

| id | tier | since |
|---|---|---|
| `weapons.effects` | experimental | 1.18.0 |

Setting up detection in general: [Modding extensions](modding-api.md).

## What it adds

A weapon your mod adds in `materials.txt` is a new piece of equipment, so the
patch's weapon fixes did not know it: no muzzle flash, smoke or buckshot, and
no automatic fire. With this extension an `Equipment` block can ask for them
with the key `Tyrs.WeaponEffects`:

| name | what the weapon gets |
|---|---|
| `Buckshot` | a spread of 14 extra tracers around the aim point |
| `Smoke` | 5 smoke puffs towards the aim point |
| `MuzzleFlash` | a muzzle flash at the barrel |
| `BurstSound` | its `Attack_` sound at most every half second, for a sound that holds a burst |
| `FullAuto` | fires automatically: 0.02 s between shots instead of 0.7 s (plus `RechargeTime`), and holding the mouse button keeps it firing in Warden Mode and Escape Mode |
| `None` | nothing; use it to take the effects away from a vanilla weapon you redefine |

The vanilla Shotgun has `Buckshot` and `Smoke`, and the AssaultRifle,
SubMachineGun and ModifiedAssaultRifle have `MuzzleFlash`, `BurstSound` and
`FullAuto`, unless your mod redefines them with the key.

On a vanilla weapon you redefine, any `Tyrs.WeaponEffects` line replaces its
built-in effects with exactly the names you list. For example, a
SubMachineGun with only `MuzzleFlash` keeps the flash and loses `BurstSound`
and `FullAuto`. `None` on its own gives no effects. The order of the lines
doesn't matter, and `None` isn't needed in front of other names. Only `None`
on a vanilla weapon has been tested in game; the rest is from the code.

## Detect it

Nothing to set up in `materials.txt`: a game without the extension ignores the
key, and your weapons work as before. To check from a script:

```lua
local HasWeaponEffects = TyrsPatch ~= nil and TyrsPatch.Has("weapons.effects")
```

## How to use it

Add one `Tyrs.WeaponEffects` line per name, like `Properties`:

```
BEGIN Equipment
    Name                 ExampleRifle
    Sprite               AssaultRifle
    Scale                1.10000
    AttackPower          4.00000
    RechargeTime         0.1000
    Range                20.0
    Ammo                 30
    TwoHanded            true
    Properties           Weapons
    Properties           RangedWeapon
    Properties           Metal
    Properties           NoImport
    Tyrs.WeaponEffects   FullAuto
    Tyrs.WeaponEffects   MuzzleFlash
    Tyrs.WeaponEffects   BurstSound
END

BEGIN Equipment
    Name                 ExampleShotgun
    Sprite               Shotgun
    Scale                1.20000
    AttackPower          25.00000
    RechargeTime         1.00000
    TwoHanded            true
    Range                10.0
    Ammo                 6
    Properties           Weapons
    Properties           RangedWeapon
    Properties           Metal
    Properties           NoImport
    Tyrs.WeaponEffects   Buckshot
    Tyrs.WeaponEffects   Smoke
END
```

## Limits

- Use the names only. A number (`Tyrs.WeaponEffects 1`) replaces the weapon's
  whole `Properties`, the same as a number after `Properties` does.
- An unknown name is ignored, with `Failed to match bitmask value` in
  `debug.txt`.
- The effects need the patch's core fixes, which are on by default: muzzle
  flash, smoke, buckshot and burst sound come from *Muzzle flash, smoke and
  buckshot*, the fire rate from *Ranged weapon fire rate*, holding the button
  from *Hold to fire automatic weapons*.
- Sounds still come from `_Tools` events named `Attack_<Name>` and
  `Reload_<Name>`, as for any weapon.

## Changes

- 1.0.0 (patch 1.18.0): first version.

## Status

Tested in game on 2026-11-18 with the two weapons above, given to armed guards
in a riot: with the extension, ExampleRifle waited 0.02 s after every shot and
showed a muzzle flash each time, and played its sound on 7 of 9 shots;
ExampleShotgun fired 5 smoke puffs and 15 tracers per shot. A weapon without
the key, and the SubMachineGun redefined with `None`, got no effects and waited
0.7 s. Without the extension the key was ignored: the example weapons fired
like any other gun, the SubMachineGun kept its effects, and nothing was logged.
Holding the button with a `FullAuto` mod weapon in Warden Mode or Escape Mode
has not been tested yet.

Patch: `patches/weapon-effects-key.patch.json`. Uses the code section
(`code-section.md`).
