# Status effects on staff and other characters (modding extension)

| id | tier | since |
|---|---|---|
| `status-effects.entities` | experimental | 1.16.0 |

Setting up detection in general: [Modding extensions](modding-api.md).

## What it adds

In the game's Lua API only prisoners have a `StatusEffects` table. With this
extension every other character has one too: staff, guards, dogs, visitors,
firemen and the rest. It is the same table as on prisoners, with the same
effect names, and an effect set on staff is kept in the save.

## Detect it

```lua
local HasStaffEffects = TyrsPatch ~= nil and TyrsPatch.Has("status-effects.entities")
```

Without it, staff have no `StatusEffects` table (`guard.StatusEffects` is
`nil`).

## How to use it

Read and set effects the way you would on a prisoner:

```lua
guard.StatusEffects.tazed = 60              -- set
local tazed = guard.StatusEffects.tazed     -- read
```

A full object script that tazes guards near the object every few game minutes,
and does nothing without the extension:

```lua
local Ready = nil
local Next = 0

function Update()
    if Ready == nil then
        Ready = TyrsPatch ~= nil and TyrsPatch.Has("status-effects.entities")
        if not Ready then
            this.Tooltip = "Needs Tyr's Community Patch with modding extensions ticked"
        end
    end
    if not Ready or Game.Time() < Next then return end
    Next = Game.Time() + 4
    for guard, distance in pairs(this.GetNearbyObjects("Guard", 6)) do
        if guard.StatusEffects.tazed < 1 then guard.StatusEffects.tazed = 60 end
    end
end
```

`Object.GiveStatusEffect` also accepts any character instead of only prisoners.
It finds the character by its script name. Not tested in game.

## Limits

The game stores and saves the effect on any character, but how a character
reacts to an effect is the game's own code. Which effects change what staff do
has not been checked yet.

## Changes

- 1.0.0 (patch 1.16.0): first version.

## Status

Tested in game on 2026-10-12 with a test mod on staff tiles: with the
extension, staff have the table, effects can be read and set, 24 staff were
saved tazed, and `TyrsPatch.Has` and `Tier` answered correctly; without it,
`TyrsPatch` is `nil` and staff have no table. The full example above was run in
game on 2026-10-13: with the extension it tazed guards; without it, it tazed
none and set its tooltip.

Patch: `patches/status-effects-entities.patch.json`. Uses the code section
(`code-section.md`).
