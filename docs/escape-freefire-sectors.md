# Escape Mode Freefire with per-sector actions

Patch: `patches/escape-freefire-sectors.patch.json` (built by
`scripts/Build-EscapeFreefireSectors.ps1`). Uses the code section
(`code-section.md`).

## What you'll notice

In Escape Mode, killing someone with your gang makes the warden order Freefire
for three minutes. With "Search and Actions per sector" on, that order had no
effect and guards kept using non-lethal force. With the fix the guards act on
it.

## What changes

When the warden gives the order, Freefire is also set in every sector, and it
is cleared again when the order ends. This only happens with per-sector actions
on. The Freefire buttons in normal play are not affected.

## Status

Not yet tested in game.
