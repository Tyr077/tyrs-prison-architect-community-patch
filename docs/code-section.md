# The `.tyrs` code section: technical notes

Target: `Prison Architect64.exe`, Steam Sunset Update. Same build and conventions
as `gang-handoff.md`.

## Why

The first fixes put their stubs in the slack at the end of `.text`
(`0x140A44260..0x140A44400`). That cave is full. Patches that need new code or
a few bytes of state now use a section appended to the executable.

## What the base patch does

`patches/code-section.patch.json` (hidden, `id: code-section`) makes four edits:

| edit | offset | change |
|---|---|---|
| `NumberOfSections` | `0x14E` | 8 to 9 |
| `SizeOfImage` | `0x198` | `0xE89000` to `0xE8A000` |
| 9th section header | `0x390` (40 bytes, all zero in the original) | `.tyrs`, VirtualSize `0x1000`, VA `0xE89000`, RawSize `0x1000`, RawPointer `0xDC1C00`, characteristics `0xE0000020` (code, execute, read, write) |
| append | `0xDC1C00` (original end of file) | `0x1000` bytes of `0xCC` |

PE facts that make this safe on this build: `e_lfanew` is `0x148`, the section
table starts at `0x250`, so the 9th header ends at `0x3B8`, inside the `0x400`
bytes of headers; `.rsrc` is the last section (VA `0xE80000`), so the new VA
`0xE89000` follows it without a gap; the file length `0xDC1C00` is already
`FileAlignment` (0x200) aligned; there is no Authenticode signature and no
Control Flow Guard (`DllCharacteristics` `0x8120`), and ASLR is off, so
`0x140E89000` is the section's address at run time.

Verified by mapping the patched image with `LoadLibraryEx(LOAD_LIBRARY_AS_IMAGE_RESOURCE)`
and reading the stub bytes back at `image + 0xE89100`.

## How the patcher handles it

- An edit whose `expect` is empty is an append: applied only when the file
  length equals its `offset`, reverted by truncating to that offset. Its state
  is presence-only; the body is meant to be written by other patches.
- A patch that uses the section declares `"requires": ["code-section"]`.
  Applying it applies the base first. Its edits inside the section carry
  `expect` bytes of `CC`, so the patcher can still tell applied from not.
  While the base is absent those edits are out of range, which counts as
  "not applied" for a patch with requirements.
- Reverting: dependents are reverted before bases, and a hidden base is
  reverted automatically once nothing applied requires it.
- The whole-file hash check reverts everything (including truncation) before
  comparing with the original hash, so a file with the section present is still
  recognised as the supported build.

## Allocation map

Data area `+0x000..+0x0FF`, code from `+0x100`; next free code offset `+0x920`. Every patch that uses the
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

`scripts/Build-CodeSection.ps1` regenerates the base patch. Build scripts for
dependents read `patches/code-section.patch.json`, apply it to the original
image and take their `expect` bytes from that.

## Antivirus

An appended read-write-execute section full of `int3` padding is the kind of
thing heuristics look at, and Windows Defender's cloud model
(`Trojan:Win32/Bearfoos.A!ml`) has quarantined one patched layout: the twelve
fixes of 1.8.0 with the booth stub at `+0x4D0` and no tweaks. Moving that stub
to `+0x500`, adding the tweaks, or removing either new fix made the same code
pass, so the score is a knife edge on bytes, not a signature. Every release
should be checked: apply the fixes-only and fixes-plus-tweaks selections to
scratch copies and scan them (`Start-MpScan -ScanType CustomScan -ScanPath`).
The build scripts take section offsets as parameters so a layout can be moved
without editing them. The structural cure would be a read-execute section with
the few bytes of writable data kept elsewhere, which changes the base patch's
header bytes and so needs `superseded` entries for upgrades.
