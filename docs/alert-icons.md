# Alert icons with custom sprite-sheet mods

Patch: `patches/alert-icons.patch.json` (built by
`scripts/Build-AlertIcons.ps1`).

## What you'll notice

With a mod that brings its own `sprites.png`, some alert icons, such as the
gang, CCTV and contraband markers, and the bakery oven glow drew the wrong part
of the sprite sheet. With the fix they draw correctly.

## What changes

These icons are now sized against the sprite sheet they come from instead of
the main one. Nothing else about how icons are drawn changes.

## Notes

Disable the Alert Icons Partial Fix mod if you use it. Its adjusted icons would
be wrong with this fix installed.

## Status

Not yet tested in game.
