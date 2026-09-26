# The code section

Some fixes need new code. For those, the patcher appends a small code section
named `.tyrs` to `Prison Architect64.exe`. It is added by the hidden base patch
`patches/code-section.patch.json` when the first fix that needs it is applied,
and removed on revert once no applied fix needs it.

## Allocation map

Data area `+0x000..+0x0FF`, code from `+0x100`; next free code offset `+0xAB0`. Every patch that uses the
section must be listed here so ranges never overlap.

| range (section offset) | VA | owner | use |
|---|---|---|---|
| `+0x000..+0x003` | `0x140E89000` | tweak-staff-death-morale-decay | `lastDay` int32, starts 0 |
| `+0x004..+0x007` | `0x140E89004` | tweak-staff-death-morale-decay | `forgiven` int32, starts 0 |
| `+0x008..+0x00F` | `0x140E89008` | tweak-staff-death-morale-decay | double 1440.0 |
| `+0x010..+0x017` | `0x140E89010` | shop-front | neighbour offset table, 8 bytes |
| `+0x018..+0x01F` | `0x140E89018` | intake-route-categories | pointer to the accepted-category bytes of the stop being loaded, 0 when none |
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

## Antivirus

Windows Defender once quarantined one patched combination (the 1.8.0 fixes
without the tweaks) as `Trojan:Win32/Bearfoos.A!ml`. Moving one stub cleared
it. Patched copies are scanned with Defender before each release.
