# Hold to fire automatic weapons

Patch: `patches/full-auto-hold.patch.json`. Uses the code section
(`code-section.md`).

## What you'll notice

When you controlled a character, holding the mouse button did not keep
automatic weapons firing: in Warden Mode every shot needed a click, and in
Escape Mode only the assault rifle kept firing. With the fix, holding the
button keeps assault rifles, SMGs and the DLC modified assault rifle firing in
both modes, at zombies too.

## What changes

Holding the button attacks whatever a click would, at the weapon's normal rate
and using ammo as a click does. Holding it over something a click cannot attack
does not repeat the "order failed" sound. Other weapons still need a click.
Guards and other characters you do not control are not affected.

## Notes

Use it with the Ranged weapon fire rate fix. Without it, Escape Mode still
waits two seconds between shots.

## Status

Not yet tested in game.
