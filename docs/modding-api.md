# Modding extensions and fix detection (for mod authors)

Tyr's Community Patch gives mods a `TyrsPatch` table. With it a mod can check
which modding extensions, bug fixes and tweaks are installed.

**Modding extensions** give mod authors things the game's Lua API could not do
before. They do nothing unless a mod uses them. All extensions are
**experimental** for now: off by default, and they may still change or be
removed between releases. Stable extensions will come later. They will change
only after discussion with mod authors, with a warning and notes on how to
update mods.

**Bug fixes and tweaks** can be checked too, for example to skip a workaround
your mod has for a bug the patch fixes.

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

When the patch is installed, the game has a `TyrsPatch` table:

- `TyrsPatch.Has(id)` is `true` when that extension, fix or tweak is installed.
- `TyrsPatch.Tier(id)` returns `"experimental"`, `"stable"` or `"deprecated"` for
  an extension, `"fix"`, `"additional"` or `"tweak"` for a fix or tweak, or
  `nil` when it is not installed.

On a game without the patch `TyrsPatch` is `nil`, so always test it first.
Otherwise `TyrsPatch.Has(...)` is a script error there.

Check for the extension or fix you need, not just for the patch: a player's
patch can be older than your mod, and an extension can be unticked while the
fixes are installed. Skip only the parts that need it, and the rest of your mod
keeps working.

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

## Checking for bug fixes and tweaks

If your mod works around a bug that the patch fixes, check for the fix and
leave your workaround out when it is installed:

```lua
local StatusEffectsFixed = TyrsPatch ~= nil and TyrsPatch.Has("lua-status-effects")

if not StatusEffectsFixed then
    -- your mod's own workaround
end
```

The id is the patch id from this table. Each page says what the fix changes.

| id | kind | what it is |
|---|---|---|
| `alert-icons` | fix | [Alert icons with custom sprite-sheet mods](alert-icons.md) |
| `direction-save` | fix | [Prisoner and staff directions not saved](direction-save.md) |
| `disarmed-armed-guards` | fix | [Disarmed armed guards can fight](disarmed-armed-guards.md) |
| `escape-freefire-sectors` | fix | [Escape Mode Freefire with per-sector actions](escape-freefire-sectors.md) |
| `exercise-grading` | fix | [Exercise on equipment counts for grading](exercise-grading.md) |
| `full-auto-hold` | fix | [Hold to fire automatic weapons](full-auto-hold.md) |
| `gang-handoff` | fix | [Gang contraband hand-off fix](gang-handoff.md) |
| `gunfire-surrender` | fix | [Prisoners near gunfire surrender](gunfire-surrender.md) |
| `intake-route-categories` | fix | [Intake routes that accept only some categories](intake-route-categories.md) |
| `keycard-door-path-cost` | fix | [Staff detour around keycard doors](keycard-door-path-cost.md) |
| `keycard-door-released-prisoners` | fix | [Released prisoners stuck behind revoked keycard doors](keycard-door-released-prisoners.md) |
| `lua-status-effects` | fix | [Lua StatusEffects assignment](lua-status-effects.md) |
| `pavilion-reload` | fix | [Armed guards reload in pavilions](pavilion-reload.md) |
| `shop-front` | fix | [Shops usable from outside the shop](shop-front.md) |
| `visitor-booth-facing` | fix | [Visitor booths facing up](visitor-booth-facing.md) |
| `visitor-door-access` | fix | [Visitors and civilians stuck at visitor doors](visitor-door-access.md) |
| `visitor-no-family` | fix | [Visitors wasted on prisoners with no family](visitor-no-family.md) |
| `visitor-spawn-tables` | fix | [Visitors in every visitation room](visitor-spawn-tables.md) |
| `weapon-effects` | fix | [Muzzle flash, smoke and buckshot](weapon-effects.md) |
| `weapon-firerate` | fix | [Ranged weapon fire-rate fix](weapon-firerate.md) |
| `tweak-armed-guard-warnings` | tweak | [Armed guard warnings ignore overall staff morale](tweaks.md) |
| `tweak-no-reoffend-fine` | tweak | [No reoffending fine (Second Chances)](tweaks.md) |
| `tweak-no-returning-prisoners` | tweak | [No returning prisoners (Second Chances)](tweaks.md) |
| `tweak-pc-shared-zones` | tweak | [Protective Custody prisoners work and attend programs in shared sectors](tweaks.md) |
| `tweak-staff-death-morale-decay` | tweak | [Staff death morale penalty fades](tweaks.md) |

Tweaks are off unless the player ticks them, so `Has` is often `false` for
them. A game patched before 1.17.0 reports nothing until the player runs the
new patcher.

## Ids and changes

Each id stands for one behaviour. A change that would break mods using an
extension or relying on a fix gets a new id, for example
`status-effects.entities.2`. The old id may stay for a while so existing mods
keep working, and `Tier` returns `"deprecated"` for an extension's old id then.
Once it is removed, `Has` returns `false` for it, so mods that were not updated
switch that part off instead of failing. Additions, crash fixes and
improvements keep the id. Each page lists its changes, and the release notes
announce them. This may change after feedback from mod authors.

## Status

Tested in game (1.17.0) without the patch, with the fixes, with the fixes and
tweaks, and with the fixes and the extension: object scripts, `world.lua` and
`grants.lua` all see `TyrsPatch` from the script's first line on whenever the
patch is installed, `Has` and `Tier` answer for the extension, a fix and a tweak
as described, and the object script example above runs as described. The game
stores the tooltip on the object; the tooltip has not been checked on screen.
