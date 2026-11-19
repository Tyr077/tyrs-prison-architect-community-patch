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

`virusdeadly` and `calamityflu` are refused on anything that is not a
prisoner: setting them does nothing and they read back as 0 (see Limits).

## Limits

The game stores and saves the effect on any character, but how a character
reacts to it is the game's own code. Each effect was set to 60 on guards,
armed guards, doctors, workmen, dogs and visitors and watched for 90 game
minutes next to untouched characters (2026-11-10):

| effect | what happened |
|---|---|
| most effects | wears off in about 30 game minutes (2 per game minute); no change seen in what the character does |
| `virus`, `StatusSwimming`, `StatusDrowning`, `StatusSmelly` | stays at the value you set; does not wear off |
| `heatstroke` | the game clears it on staff within a few minutes; dogs keep it |
| `infected` | the character is replaced straight away: guards, doctors and visitors became zombies; the workman, armed guard and dog were gone with no zombie in their place |
| `virusdeadly`, `calamityflu` | refused on non-prisoners (they crashed the game) |

"No change seen" means movement, damage, equipment and other effects looked
the same as for the untouched characters. Tazed guards keep walking, for
example. Each effect was tried on one character per type.

`Object.GiveStatusEffect` cannot be used by mods: it does not exist in object
scripts, and calling `Game.GiveStatusEffect` from `world.lua` crashes the game.

## Changes

- 1.0.0 (patch 1.16.0): first version.
- 1.0.1 (patch 1.17.0): no change for mods (the patch's own detection entry moved).
- 1.1.0 (patch 1.18.0): giving a non-prisoner `virusdeadly` or `calamityflu`
  crashed the game, and so did loading a save with such a character on a game
  without the patch. Both effects are now refused on non-prisoners. Saves made
  with 1.0.x that already contain such a character load again.

## Status

Tested in game on 2026-10-12 with a test mod on staff tiles: with the
extension, staff have the table, effects can be read and set, 24 staff were
saved tazed, and `TyrsPatch.Has` and `Tier` answered correctly; without it,
staff have no table. The full example above was run in
game on 2026-10-13: with the extension it tazed guards; without it, it tazed
none and set its tooltip.

1.1.0 was tested in game on 2026-11-10 with all 27 effects on six character
types: no crash, effects read back (the two refused ones read 0) and are kept
in the save, a patched game reads them back after loading, and the unpatched
game loads and plays the save.

Patch: `patches/status-effects-entities.patch.json`. Uses the code section
(`code-section.md`).
