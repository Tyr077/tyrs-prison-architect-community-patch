# Disarmed armed guards can fight

Patch: `patches/disarmed-armed-guards.patch.json`. Uses the code section
(`code-section.md`).

An enhancement: on by default, and can be unticked in the patcher.

## What you'll notice

An armed guard who has lost its shotgun could not fight back while Freefire was
on or once it was badly hurt. With the patch it fights with its fists instead.

Since 1.1.0 its fists are also drawn while it has no weapon.

## What changes

When the game picks the weapon an armed guard fights with, a guard carrying
nothing now gets its fists. Armed guards that still have their shotgun are not
affected.

An armed guard carrying nothing is drawn holding its fists, using the game's
own hand sprite. Guards that are carrying something else, or are incapacitated,
are drawn as before.

## Status

Not yet tested in game. The fists showing (1.1.0) is untested too.
