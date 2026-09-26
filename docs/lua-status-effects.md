# Scripted status effects (mods)

Patch: `patches/lua-status-effects.patch.json`. Uses the code section
(`code-section.md`).

## What you'll notice

Mods that set prisoner status effects from Lua, such as Less Lethal Expansion,
had no effect: a prisoner the mod tazed or sedated was not actually tazed or
sedated. With the fix the effects apply.

## What changes

Setting a prisoner's status effect from Lua now turns the effect on. It then
wears off at its normal rate and is kept in the save.

## Status

Tested in game.

## Notes

For mod authors: Lua `StatusEffects` assignments, such as
`prisoner.StatusEffects.tazed = 60`, now take effect.
