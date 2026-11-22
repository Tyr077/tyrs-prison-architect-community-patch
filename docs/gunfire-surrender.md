# Prisoners near gunfire surrender

Patch: `patches/gunfire-surrender.patch.json`. Uses the code section
(`code-section.md`).

## What you'll notice

When an armed guard opened fire, only the prisoner being shot at could
surrender. With the fix, prisoners near the shot can surrender too.

## What changes

Each gunshot by an armed guard, a soldier or a sniper makes up to ten prisoners
within four squares of the shooter or of the target react as if they had been
shot at. There is no cooldown, so an automatic weapon does this for every round.
Tazer shots do not trigger it, and neither do shots by anyone else, such as
prisoners (including your gang in Escape Mode) or bounty hunters.

Before 1.1.0 every shot except a prisoner's counted. Prisoners can't surrender to
a bounty hunter, so instead they attacked it: bounty hunters shooting at zombies
set the prisoners nearby on themselves.

## Status

Tested in game: prisoners near the shot react (none in 142 shots without the
fix, 29 in 106 shots with it, at most ten per shot). Whether more of them end
up surrendering during a riot is not confirmed.

1.1.0 tested in game with the reported save: bounty hunters shooting at zombies
set off 67 reactions in nearby prisoners with 1.0.1 and none with 1.1.0.
