# Alert icons with custom sprite-sheet mods: technical notes

Target: `Prison Architect64.exe`, Steam Sunset Update. Same build and conventions
as `gang-handoff.md`.

## Symptom

With any mod that ships its own `sprites.png`, the notification icons that live
in `objects_d11_2.png` draw garbage: the wrong quarter of the sheet. Affected
icons include the gang demand, gang target, gang play and gang leader
assassination markers, CCTV misconduct, tracking-belt health and router alerts,
overheating objects, tropical fever, chewed fences, fallen trees, the plumbers
and repairmen on-site markers, contraband markers, and the bakery oven glow.
The community "Alert Icons Partial Fix" mod ships a replacement
`objects_d11_2.spritebank` with every affected sprite's `x`, `y`, `w`, `h`
doubled, which compensates for the engine error but cannot fix sprites that are
also drawn in the world, which is why three alerts stayed broken.

## Sprite banks

| item | location |
|---|---|
| App global | `0x140D57900` |
| Objects bank (main atlas) | `App + 0x730` |
| Extra bank array | `App + 0x7B0`; `[0]` = objects_d11, `[1]` = objects_d11_2 |
| SpriteBank fields | `+0x00` texture, `+0x60` 1/cellsX, `+0x64` 1/cellsY, `+0x68`/`+0x6C` half-pixel pad |
| MarkerIcon fields | `+0x34` sprite index, `+0x38` bank index (-1 = Objects), `+0x40` scale |

The Objects atlas is composited at load (`FUN_14040a870`, `FUN_140409630`) from
objects.png, people.png, special-entities.png, objectsTexture_d11.png and every
mod's sprites.png. Without mods it is 4096 px, the same size as
objects_d11_2.png, so both banks have the same cell scale. Mod sheets make the
atlas larger, and the two scales diverge.

## Defect

`FUN_1405fd080` (MarkerIcon::DrawSprite) fetches the sprite from the bank the
icon names, but every texture-coordinate calculation reads the scale fields of
the Objects bank:

```
mov  r8, rax                    ; bank index
mov  rax, [App]
mov  rcx, [rax+0x7B0]
mov  rcx, [rcx+r8*8]            ; the right bank, but only in a volatile register
call FUN_1403fde20              ; sprite
...
mov  r14, [App]
lea  rbx, [r14+0x730]           ; RBX = Objects bank
...  [rbx+0x60] [rbx+0x64] [rbx+0x68] [rbx+0x6C]   ; scale from the wrong bank
```

`FUN_1406cff30`, which draws the bread oven glow (objects_d11_2 sprite 0x43)
over a working oven, has the same mistake with `App+0x790..0x79C` (the Objects
bank's fields addressed through App).

Every other objects_d11_2 draw site checked (`FUN_14042a6c0`, `FUN_140511800`,
`FUN_14048cbc0`, the object renderer `FUN_1404def80`) uses the fetched bank
consistently.

## Edits

MarkerIcon::DrawSprite:

| site | original | new |
|---|---|---|
| `0x1405FD4F0` (21 bytes) | `mov r8,rax; mov rax,[App]; mov rcx,[rax+0x7B0]; mov rcx,[rcx+r8*8]` | `mov rcx,[App]; mov rcx,[rcx+0x7B0]; mov rbx,[rcx+rax*8]; mov rcx,rbx` |
| `0x1405FD524` (7 bytes) | `lea rbx,[r14+0x730]` | 7-byte NOP |

RBX is callee-saved, so it survives the sprite lookup call, and it was only
ever assigned at the NOPed instruction, so nothing else depended on it holding
the Objects bank. The rect helper call, the four scale loads and the draw now
all use the bank the sprite came from. The texture fetch already used the right
bank and is unchanged.

Oven glow:

| site | original | new |
|---|---|---|
| `0x1406CFFE0` | `mov rcx,[rax+0x7B0]` | `mov rbx,[rax+0x7B0]` |
| `0x1406CFFFE` | `mov rcx,[rcx+8]` | `mov rcx,[rbx+8]` |
| `0x1406D0033` (30 bytes) | two scale loads via `[rcx+0x798]`/`[rcx+0x79C]` | `mov rbx,[rbx+8]` then `[rbx+0x68]`/`[rbx+0x6C]`, 2-byte NOP |
| `0x1406D005B` (16 bytes) | `[rcx+0x790]`/`[rcx+0x794]` | `[rbx+0x60]`/`[rbx+0x64]`, 6-byte NOP |

RCX stays equal to App because the function reads the World pointer through it
later. RBX held the object pointer, which is not read after the sprite lookup.

No code cave is used. `scripts/Build-AlertIcons.ps1` assembles the patch.

## Compatibility

With this fix installed, the "Alert Icons Partial Fix" mod must be disabled: its
doubled coordinates would now be wrong. Mods that only add sprites are
unaffected and are exactly the case this fixes.
