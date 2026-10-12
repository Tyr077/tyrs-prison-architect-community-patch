# Modding extensions

Modding extensions give mod authors things the game's Lua API could not do
before. They do nothing unless a mod uses them.

- **Stable** extensions are on by default. Their Lua names and behaviour do not
  change in later releases; new things are only added.
- **Experimental** extensions are off by default (tick them in the patcher, or
  `--apply --experimental` on the command line). They may still change or be
  removed between releases.

## Checking for an extension

Every Lua state (object scripts, `world.lua`, `grants.lua`) gets a `TyrsPatch`
table while at least one modding extension is installed:

```lua
if TyrsPatch and TyrsPatch.Has("status-effects.entities") then
    -- the extension is installed
end
TyrsPatch.Tier("status-effects.entities")   -- "stable", "experimental", or nil if not installed
```

On a game without the patch, or with no extension ticked, `TyrsPatch` is `nil`.
Write mods so they still work then.

## Extensions

| id | tier | since | what it adds |
|---|---|---|---|
| `status-effects.entities` | experimental | 1.16.0 | `StatusEffects` on staff and every other character ([details](status-effects-entities.md)) |
