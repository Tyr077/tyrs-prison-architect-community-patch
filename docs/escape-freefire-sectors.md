# Escape Mode Freefire with per-sector actions: technical notes

Target: `Prison Architect64.exe`, Steam Sunset Update. Same build and conventions
as `gang-handoff.md`. Needs the code section (`code-section.md`).

## Symptom

In Escape Mode, killing someone with your gang makes the warden order Freefire
for three minutes. With the "Search and Actions per sector" option on, which is
the default, the order has no effect: guards keep using non-lethal force.

## Cause

The Escape Mode kill handler `FUN_1405561C0` gives the order by setting the
legacy prison-wide Freefire flag `World+0x4614` and `WeaponsFreeTimer`
(`EscapeMode+0x110`) to 180. The Escape Mode update `FUN_140552F10` counts the
timer down and writes 0 to `World+0x4614` whenever it is below zero.

Since per-sector actions were added, the emergency orders live in the
`CrisisSectorData` table, 11 orders by 14 sectors at
`World+0x44C8 + order*14 + sector` (save keys `"order sector"`, loader
`FUN_1407C8880`). Order 1 is WeaponsFree, so its row is
`World+0x44D6..+0x44E3`. When per-sector actions are on (`World+0x4715`, with
the option `FUN_1401C6B50(3,1)`), guards read their sector's entry
(`FUN_14053B9C0`) instead of the legacy flag: `GetEquipmentDef` for snipers and
the ArmedGuard update `FUN_1404882B0` for drawing weapons. The warden's order
sets only the flag they no longer read.

## Fix

Both places that touch `World+0x4614` also write the WeaponsFree row, for all 14
sectors, when `World+0x4715` is set.

1. `0x14055634C` in the kill handler (`mov rax,[App]`, 7 bytes) jumps to
   `.tyrs+0x7F0`, which redoes `mov rax,[App]` / `mov rcx,[rax+0x198]` /
   `mov byte [rcx+0x4614],1`, then, if `[rcx+0x4715]` is set, writes `01` to
   `World+0x44D6..+0x44E3`, and resumes at `0x140556361` (the timer write).
2. `0x140553157` in the update (`mov [rcx+0x4614],bpl` with `bpl = 0`,
   `rcx = World`, 7 bytes) jumps to `.tyrs+0x840`, which does the same write,
   then clears the row under the same condition, and resumes at `0x14055315E`.

Neither stub calls anything. This mirrors what the game has always done with
the legacy flag, including clearing it on every update while the timer is
expired.

`scripts/Build-EscapeFreefireSectors.ps1` builds the patch; `-OnAt` and `-OffAt`
move the stubs.

## Verified

Disassembly of a patched copy. Not yet seen in a running game.

## Not changed

Only Escape Mode's automatic order is affected; the player's Freefire buttons in
normal play are untouched. The All-in-One tracker also notes that snipers use
the per-sector entry even when the option is turned off; that is a different
check and not part of this fix.
