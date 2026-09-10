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

Data area `+0x000..+0x0FF`, code from `+0x100`. Every patch that uses the
section must be listed here so ranges never overlap.

| range (section offset) | VA | owner | use |
|---|---|---|---|
| `+0x000..+0x003` | `0x140E89000` | tweak-staff-death-morale-decay | `lastDay` int32, starts 0 |
| `+0x008..+0x00F` | `0x140E89008` | tweak-staff-death-morale-decay | double 1440.0 |
| `+0x100..+0x14B` | `0x140E89100` | tweak-staff-death-morale-decay | stub, 76 bytes |

`scripts/Build-CodeSection.ps1` regenerates the base patch. Build scripts for
dependents read `patches/code-section.patch.json`, apply it to the original
image and take their `expect` bytes from that.
