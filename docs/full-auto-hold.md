# Hold to fire automatic weapons

Patch: `patches/full-auto-hold.patch.json`. Uses the code section
(`code-section.md`).

A core fix: on by default, and can be unticked in the patcher.

## What you'll notice

When you controlled a character, holding the mouse button did not keep
automatic weapons firing: in Warden Mode every shot needed a click, and in
Escape Mode only the assault rifle kept firing. With the patch, holding the
button keeps assault rifles, SMGs and the DLC modified assault rifle firing in
both modes, at zombies too.

## What changes

Holding the button attacks whatever a click would, at the weapon's normal rate
and using ammo as a click does. Holding it over something a click cannot attack
does not repeat the "order failed" sound. Other weapons still need a click,
except mod weapons that ask for `FullAuto`
([Weapon effects for mod weapons](weapon-effects-key.md)).
Guards and other characters you do not control are not affected.

## Notes

Use it with the Ranged weapon fire rate fix. Without it, Escape Mode still
waits two seconds between shots.

## Status

Tested in game. In Warden Mode during a riot, holding the button kept the SMG
firing, and the pistol still fired once per click. In Escape Mode it kept the
SMG and the assault rifle firing. The modified assault rifle and shooting at
zombies are not tested.
