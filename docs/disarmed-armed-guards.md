# Disarmed armed guards can fight

Patch: `patches/disarmed-armed-guards.patch.json`. Uses the code section
(`code-section.md`).

An enhancement: on by default, and can be unticked in the patcher.

## What you'll notice

An armed guard who has lost its shotgun could not fight back while Freefire was
on or once it was badly hurt. With the patch it fights with its fists instead,
and raises them and jabs like a prisoner in a brawl.

## What changes

When the game picks the weapon an armed guard fights with, a guard carrying
nothing now gets its fists. Armed guards that still have their shotgun are not
affected.

The game draws an armed guard's fists only while its weapon is holstered, so a
disarmed guard punching under Freefire showed no fists. That check now also
treats a guard carrying nothing as holstered, so the game's own fists show.

1.1.0 and 1.2.0 drew fists of their own instead. In game they showed a stray
white hand (1.1.0) and hands held where no other character holds them, and they
hid the game's fists. 1.3.0 removes that drawing; the patcher upgrades or
removes an older version cleanly.

## Status

Checked in game on 2026-10-05 (riot save, guards disarmed by a probe): a
disarmed guard with its weapon drawn gets the Fists and is drawn with the
game's fists (`fists-check`), and a 1.14.0 install upgrades to the same file as
a fresh install and reverts to the original.
