# Released prisoners behind revoked keycard doors

Patch: `patches/keycard-door-released-prisoners.patch.json` (built by
`scripts/Build-KeycardDoorRelease.ps1`).

## What you'll notice

When a keycard door with prisoner access revoked was the only way out, released
prisoners stood still. With the fix they walk to the door and a guard
lets them out.

## What changes

At a keycard door with prisoner access revoked, released prisoners now wait for
a guard to open it, as they would at any other locked door.

Prisoners serving time are still refused, except misbehaving or escorted
prisoners, who now also wait for a guard there (not tested). Visitors and other
non-staff without a key also wait for a guard there instead of being refused
(not tested).

## Status

Tested in game.
