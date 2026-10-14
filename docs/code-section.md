# The code section

Some fixes need new code. For those, the patcher appends a small code section
named `.tyrs` to `Prison Architect64.exe`. It is added by the hidden base patch
`patches/code-section.patch.json` when the first fix that needs it is applied,
and removed on revert once no applied fix needs it.

It is 16 KiB since 3.0.0 (patcher 1.17.0); 2.0.0 was 8 KiB and 1.0.0 4 KiB. A
game file with a smaller section is grown in place, keeping what is in it.

## Allocation map

Fixes: data area `+0x000..+0x0FF`, code `+0x100..+0xFFF`, next free code offset `+0xD30`, then the
second fix code area `+0x3000..+0x3FFF` (free). Modding extensions: `+0x1000..+0x1FFF`, next free offset
`+0x1550`. TyrsPatch core and registry: `+0x2000..+0x2FFF`. Every patch that uses the section must be
listed here so ranges never overlap. Ranges marked reserved held code or text in an earlier release; they
stay unused so older installs are still recognised.

| range (section offset) | VA | owner | use |
|---|---|---|---|
| `+0x000..+0x003` | `0x140E89000` | tweak-staff-death-morale-decay | `lastDay` int32, starts 0 |
| `+0x004..+0x007` | `0x140E89004` | tweak-staff-death-morale-decay | `forgiven` int32, starts 0 |
| `+0x008..+0x00F` | `0x140E89008` | tweak-staff-death-morale-decay | double 1440.0 |
| `+0x010..+0x017` | `0x140E89010` | shop-front | neighbour offset table, 8 bytes |
| `+0x018..+0x01F` | `0x140E89018` | intake-route-categories | pointer to the accepted-category bytes of the stop being loaded, 0 when none |
| `+0x020..+0x023` | `0x140E89020` | visitor-spawn-tables (1.1.0) | visitor spawns so far this session, int32, starts 0 |
| `+0x100..+0x166` | `0x140E89100` | tweak-staff-death-morale-decay | stub, 103 bytes |
| `+0x170..+0x1C9` | `0x140E89170` | lua-status-effects | stub, 90 bytes |
| `+0x1D0..+0x243` | `0x140E891D0` | exercise-grading | stub, 116 bytes |
| `+0x250..+0x2EF` | `0x140E89250` | shop-front | TryNeighbours, 160 bytes |
| `+0x320..+0x39A` | `0x140E89320` | shop-front | reach stub, 123 bytes |
| `+0x3A0..+0x408` | `0x140E893A0` | shop-front | permission stub, 105 bytes |
| `+0x410..+0x482` | `0x140E89410` | intake-route-categories | queue scan stub, 115 bytes |
| `+0x4A0..+0x4C2` | `0x140E894A0` | intake-route-categories | spawn wrapper, 35 bytes |
| `+0x500..+0x523` | `0x140E89500` | visitor-booth-facing | pairing-check slot stub, 36 bytes |
| `+0x530..+0x705` | `0x140E89530` | weapon-effects | effects stub, 470 bytes (constants at the end) |
| `+0x710..+0x782` | `0x140E89710` | weapon-effects | burst-sound stub, 115 bytes |
| `+0x790..+0x7CC` | `0x140E89790` | pavilion-reload | reload stub, 61 bytes |
| `+0x7D0..+0x7E2` | `0x140E897D0` | disarmed-armed-guards | weapon-drawn stub, 19 bytes |
| `+0x7F0..+0x839` | `0x140E897F0` | escape-freefire-sectors | Freefire on stub, 74 bytes |
| `+0x840..+0x87B` | `0x140E89840` | escape-freefire-sectors | Freefire off stub, 60 bytes |
| `+0x880..+0x89B` | `0x140E89880` | full-auto-hold | Escape Mode stub, 28 bytes |
| `+0x8A0..+0x8EC` | `0x140E898A0` | full-auto-hold | warden mode stub, 77 bytes (64 of code since 1.1.0, rest `CC`) |
| `+0x8F0..+0x916` | `0x140E898F0` | full-auto-hold | warden held-frame refusal stub, 39 bytes |
| `+0x920..+0x96A` | `0x140E89920` | weapon-firerate (2.0.0) | ReloadTimer-by-weapon stub, 75 bytes |
| `+0x970..+0xAA5` | `0x140E89970` | gunfire-surrender | area surrender stub, 310 bytes (4.0f constant at the end) |
| `+0xAB0..+0xAE4` | `0x140E89AB0` | disarmed-armed-guards (1.1.0-1.2.0) | entity draw held-item stub, 53 bytes; given back in 1.3.0 (`CC`), kept reserved so older installs upgrade |
| `+0xAF0..+0xB12` | `0x140E89AF0` | visitor-spawn-tables | skip-unpaired-table stub, 35 bytes |
| `+0xB20..+0xB43` | `0x140E89B20` | disarmed-armed-guards (1.2.0) | held-item draw skip stub, 36 bytes; given back in 1.3.0, kept reserved |
| `+0xB50..+0xC9F` | `0x140E89B50` | disarmed-armed-guards (1.2.0) | hand positions stub, 336 bytes; given back in 1.3.0, kept reserved |
| `+0xCA0..+0xD0D` | `0x140E89CA0` | visitor-spawn-tables (1.1.0) | table-list rotation stub, 110 bytes |
| `+0xD10..+0xD2A` | `0x140E89D10` | visitor-no-family | pairing prisoner-test stub, 27 bytes |
| `+0x1000..+0x107F` | `0x140E8A000` | modapi-core 1.0.0 | Lua text, part 1; moved to `+0x2000` in 2.0.0, reserved |
| `+0x1080..+0x127F` | `0x140E8A080` | modapi-core 1.0.0 registry | 8 slots of `0x40`; slot 0 was status-effects-entities 1.0.0; reserved |
| `+0x1280..+0x1303` | `0x140E8A280` | modapi-core 1.0.0 | Lua text, part 2; reserved |
| `+0x1400..+0x1544` | `0x140E8A400` | status-effects-entities | RegisterLua stub, string helper, entity test for GiveStatusEffect (`+0x1520`) |
| `+0x2000..+0x207F` | `0x140E8B000` | modapi-core (2.0.0) | Lua text, part 1 (`print = Game.DebugOut`, registry loop) |
| `+0x2080..+0x2C7F` | `0x140E8B080` | registry | 64 slots of `0x30`, each written by its own patch (`scripts/build_registry.py`); slots below |
| `+0x2C80..+0x2D03` | `0x140E8BC80` | modapi-core (2.0.0) | Lua text, part 2 (`TyrsPatch` table) |

## Registry slots

Slot `n` is at `+0x2080 + n * 0x30` and holds `|<id>=<kind>|`. Slots never move once released; new patches
take the next free slot.

| slot | patch | slot | patch |
|---|---|---|---|
| 0 | status-effects-entities (`status-effects.entities`) | 13 | pavilion-reload |
| 1 | alert-icons | 14 | shop-front |
| 2 | direction-save | 15 | visitor-booth-facing |
| 3 | disarmed-armed-guards | 16 | visitor-door-access |
| 4 | escape-freefire-sectors | 17 | visitor-no-family |
| 5 | exercise-grading | 18 | visitor-spawn-tables |
| 6 | full-auto-hold | 19 | weapon-effects |
| 7 | gang-handoff | 20 | weapon-firerate |
| 8 | gunfire-surrender | 21 | tweak-armed-guard-warnings |
| 9 | intake-route-categories | 22 | tweak-no-reoffend-fine |
| 10 | keycard-door-path-cost | 23 | tweak-no-returning-prisoners |
| 11 | keycard-door-released-prisoners | 24 | tweak-pc-shared-zones |
| 12 | lua-status-effects | 25 | tweak-staff-death-morale-decay |

## Antivirus

Windows Defender once quarantined one patched combination (the 1.8.0 fixes
without the tweaks) as `Trojan:Win32/Bearfoos.A!ml`. Moving one stub cleared
it. Patched copies are scanned with Defender before each release.
