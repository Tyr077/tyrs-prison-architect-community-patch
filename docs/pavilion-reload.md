# Armed guards reload in pavilions

Patch: `patches/pavilion-reload.patch.json`. Uses the code section
(`code-section.md`).

## What you'll notice

An armed guard manning a Guard Pavilion fired once and never again. The same
went for modded guards with ranged weapons. With the fix it keeps firing, with
the same wait between shots as a guard on foot.

## What changes

A guard stationed on a pavilion now counts down its reload time, which the game
had skipped for it. When the reload finishes it plays the reload sound and
drops a shell casing, like any other guard. Nothing else about stationed guards
changes.

## Status

Not yet tested in game.
