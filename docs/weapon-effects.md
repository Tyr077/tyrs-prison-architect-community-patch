# Muzzle flash, smoke and buckshot

Patch: `patches/weapon-effects.patch.json` (built by
`scripts/Build-WeaponEffects.ps1`). Uses the code section
(`code-section.md`).

## What you'll notice

Every gunshot drew a single thin tracer: no muzzle flash on assault rifles and
SMGs, and no smoke or spread of buckshot from the shotgun. Automatic rifles
also played their firing sound for every round. With the fix, assault rifles
and SMGs show a muzzle flash, the shotgun fires a spread of buckshot with
smoke, and automatic rifles play the firing sound at most every half second.

## What changes

Each shot from an assault rifle, SMG, the DLC modified assault rifle or a
shotgun now adds its effects. Only what you see and hear changes. Damage, hit
chance and fire rate are not affected.

## Status

Not yet tested in game.
