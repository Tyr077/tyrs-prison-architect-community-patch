# Muzzle flash, smoke and buckshot

Patch: `patches/weapon-effects.patch.json`. Uses the code section
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
chance and fire rate are not affected. Mod weapons can ask for the same effects
([Weapon effects for mod weapons](weapon-effects-key.md)).

## Status

Tested in game with armed guards in a riot. Without the fix every shot drew one
tracer, with no smoke or muzzle flash. With it the shotgun fired 15 tracers and 5
smoke puffs per shot, the assault rifle, SMG and modified assault rifle showed a
muzzle flash on every shot, and the automatic rifles played the firing sound on
fewer than every shot. The modified assault rifle fired only once in the test.
