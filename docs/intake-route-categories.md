# Intake with route-restricted categories

Patch: `patches/intake-route-categories.patch.json`. Uses the code section
(`code-section.md`).

## What you'll notice

With a helipad, boat dock or road set to accept only some prisoner categories,
intake could stop for good and the sidebar said *Your prison is closed to new
inmates* while cells stood empty. With the fix, prisoners keep arriving.

## What changes

A vehicle now picks up only prisoners of the categories its stop accepts and
leaves the rest queued for a route that does.

## Status

Not yet tested in game.

## Notes

Every intake category you take still needs at least one route that accepts it.
Ozoneraxi's findings on the AIO tracker showed which route settings trigger it.
