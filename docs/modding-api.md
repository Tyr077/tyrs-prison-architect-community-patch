# Modding extensions (for mod authors)

Modding extensions give mod authors things the game's Lua API could not do
before. They do nothing unless a mod uses them.

All extensions are **experimental** for now: off by default, and they may still
change or be removed between releases. Stable extensions will come later. They
will change only after discussion with mod authors, with a warning and notes on
how to update mods.

## Available extensions

| extension | id | tier | since | what it adds |
|---|---|---|---|---|
| [Status effects on staff and other characters](status-effects-entities.md) | `status-effects.entities` | experimental | 1.16.0 | a `StatusEffects` table on staff and every other character, like prisoners have |

Each extension's page shows how to detect it and how to use it.

## What players need

Players install the patch and tick **Modding extensions** in the patcher, which
turns on all of them (`--apply --experimental` on the command line). Keep the
core fixes on too; the extensions were tested with them.

Say so in your mod's description, for example: *"Optional: with Tyr's Prison
Architect Community Patch and its Modding extensions ticked, guards can also be
tazed."*

## Setting up detection

When an extension is installed, the game has a `TyrsPatch` table:

- `TyrsPatch.Has(id)` is `true` when that extension is installed.
- `TyrsPatch.Tier(id)` returns `"experimental"`, `"stable"`, `"deprecated"`, or
  `nil` when it is not installed.

On a game without the patch, or with the box unticked, `TyrsPatch` is `nil`, so
always test it first. Otherwise `TyrsPatch.Has(...)` is a script error there.

Check for the extension you use, not just for the patch: a player's patch can be
older than your mod. Skip only the parts that need the extension, and the rest of
your mod keeps working. Bug fixes need no check.

`TyrsPatch` is there from a script's first line, so you can check at the top of
the file or inside a function.

### In an object script

An object with `Properties Scripted` runs `data/scripts/<ObjectName>.lua`. Check
once, and use the object's tooltip to tell the player what is missing:

```lua
local Ready = nil          -- nil until checked

function Update()
    if Ready == nil then
        Ready = TyrsPatch ~= nil and TyrsPatch.Has("status-effects.entities")
        if not Ready then
            this.Tooltip = "Needs Tyr's Community Patch with modding extensions ticked"
        end
    end
    if not Ready then return end
    -- code that uses the extension
end
```

### In `world.lua` or `grants.lua`

```lua
local HasStaffEffects = TyrsPatch ~= nil and TyrsPatch.Has("status-effects.entities")

function Update(elapsed)           -- world.lua; in grants.lua, CreateGrants()
    if not HasStaffEffects then return end
    -- code that uses the extension
end
```

These scripts have no object to put a tooltip on, so leave the message to your
mod's description. In our tests, `Game.AdviserSay` from a mod's `world.lua`
crashed the game without the patch, so don't use it for this message.

## Ids and changes

Each id stands for one behaviour. A change that would break mods using an
extension gets a new id, for example `status-effects.entities.2`. The old id may
stay for a while so existing mods keep working, and `Tier` returns
`"deprecated"` for it then. Once it is removed, `Has` returns `false` for it, so
mods that were not updated switch that part off instead of failing. Additions
and crash fixes keep the id. Each extension's page lists its changes, and the
release notes announce them. This may change after feedback from mod authors.

## Status

Tested in game (1.16.0) without the patch, with the fixes only, and with the
extension: object scripts, `world.lua` and `grants.lua` all see `TyrsPatch`,
from the script's first line on, only when the extension is installed. The
object script example above runs as described, and the game stores the tooltip
on the object; the tooltip has not been checked on screen.
