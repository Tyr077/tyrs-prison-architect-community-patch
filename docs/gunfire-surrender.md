# Prisoners near gunfire surrender

Patch: `patches/gunfire-surrender.patch.json` (built by
`scripts/Build-GunfireSurrender.ps1`). Uses the code section
(`code-section.md`).

## What you'll notice

When an armed guard opened fire, only the prisoner being shot at could
surrender. With the fix, prisoners near the shot can surrender too.

## What changes

Each gunshot makes up to ten prisoners within four squares of the shooter or of
the target react as if they had been shot at. There is no cooldown, so an
automatic weapon does this for every round. Shots fired by prisoners, including
your gang in Escape Mode, and Tazer shots do not trigger it.

## Status

Not yet confirmed in game.
