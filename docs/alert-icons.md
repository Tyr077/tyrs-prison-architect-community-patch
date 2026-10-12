# Alert icons with custom sprite-sheet mods

Patch: `patches/alert-icons.patch.json`.

## What you'll notice

With a mod that brings its own `sprites.png`, some pictures that come from the
game's second object sheet drew the wrong part of it: alert icons such as the
gang, CCTV and contraband markers, the bakery oven glow, the rider on the
bounty hunters' trike (Undead DLC), and object pictures in panels such as the
staff report. With the fix they draw correctly.

## What changes

These pictures are now sized against the sprite sheet they come from instead
of the main one. Nothing else about how they are drawn changes.

## Notes

Disable the Alert Icons Partial Fix mod if you use it. Its adjusted icons would
be wrong with this fix installed.

## Status

1.0.0 (alert icons, oven glow): confirmed in game on 2026-10-05 with a mod that
ships its own `sprites.png`. 1.1.0: the trike rider was checked in game on
2026-10-12 with a test mod that enlarges the sprite sheet (drawn from the
wrong place before, the right place with the fix); the panel pictures were
checked in a patched copy of the game only.
