# Status effects on staff and other characters (modding extension)

Patch: `patches/status-effects-entities.patch.json`. Experimental, off by
default. Feature id `status-effects.entities`. Uses the code section
(`code-section.md`).

## What it adds

In the game's Lua API only prisoners have a `StatusEffects` table. With this
extension every character has one: staff, guards, dogs, visitors, firemen and
the rest. It works the same way as on prisoners:

```lua
for guard, distance in pairs(this.GetNearbyObjects("Guard", 10)) do
    guard.StatusEffects.tazed = 60      -- 0 clears it
end
```

`Object.GiveStatusEffect` also accepts any character instead of only prisoners.
It finds the character by its script name, which only scenario maps give.

## Limits

The game stores the effect on any character, but how a character reacts to an
effect is the game's own code. Which effects change what staff do has not been
checked yet.

## Status

Tested in game on 2026-10-12 with a test mod on staff tiles: with the
extension, staff have the table, 24 staff were saved tazed, and `TyrsPatch.Has`
and `Tier` answered correctly; without it, `TyrsPatch` is `nil` and staff have no
table. `Object.GiveStatusEffect` on staff is not tested in game.
