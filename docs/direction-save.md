# Prisoner and staff directions not saved: technical notes

Target: `Prison Architect64.exe`, Steam Sunset Update. Same build and conventions
as `gang-handoff.md`.

## Symptom

Direction markings placed for prisoners or staff are gone after loading a save.
vojin154 reported and fixed this first (pa_fix_direction_serialization); the
notes below are our own analysis of the same bug, which turned out to be wider
than the two direction fields.

## Save pipeline

Every saveable object owns a `DataRegistry` (vtable `0x140AC0508`): a list of
entries created by `DataRegistry::Register` (`FUN_1401c2d20`) with a type code,
a pointer into the object and a name. The type codes:

| type | storage | text writer |
|---|---|---|
| 1 | int (optionally with an enum-name table) | yes |
| 2 | float | yes |
| 3 | one byte (char) | **no** |
| 4 | string | yes |
| 5 | bool | yes |
| 7 | double | yes |
| 9 | int64 | no |

Saving: `DataRegistry::Write` (`FUN_1401c3910`) turns each entry into a node in
a `Directory` tree, copying the type code into the node, then
`Directory::WritePlainText` (`FUN_140165350`) serialises the tree as the
`BEGIN ... END` text of a `.prison` file. Its value switch handles node types
1, 2, 4, 5 and 7. Anything else hits

```
Directory ERROR : Writing Plain Text, unsupported data type
```

and the key is written with no value. On load the text reader
(`Directory::ReadPlainText`, `FUN_140164c50`) reports
"Unexpected EOL reading corresponding value for key" and discards the key.

Loading: `DataRegistry::Read` (`FUN_1401c3530`) case 3 already calls
`Node::GetAsNumber` (`FUN_140165f40`), which accepts int, float, char, bool,
double and string nodes, and stores the result as one byte. So the read side
never needed a type-3 node; only the write side produced one.

The binary tree format (`FUN_140165b70` / `FUN_140165d50`) does handle type 3,
which is presumably why the omission went unnoticed.

## Type-3 fields in the game

Every `Register` call with type 3, found by scanning for the immediate before
each call:

| owner | fields |
|---|---|
| Cell / tile (`FUN_1407b1410`) | `PrisonDir` (+0x40), `StaffDir` (+0x41) |
| Civilian (`FUN_1404afd80`) and Visitor (`FUN_140761010`) | `sc_r sc_g sc_b`, `cc_r cc_g cc_b` (skin and clothing colour) |
| colour helper `FUN_1401c2b20` (`.r .g .b .a`) | used by a particle-emitter registry (`FUN_1403f3520`, `c1`/`c2`) and a small colour+link record (`FUN_140488da0`, `c`) |

None of these ever reach a save file in the unpatched game. A vanilla save of a
prison with directions placed contains no `PrisonDir`, `StaffDir` or `sc_r`
keys at all, because the value is dropped and, when the field equals its
default, the entry is skipped entirely.

Note the tile registry also looks up `"PrisonerDir"` (with the typo) to attach
enum names, and `"StaffDir"` with a check that the entry is type 1, so neither
direction field gets names. `VisitorDir` (+0xCC) is a type-1 int with names and
saves correctly.

## Fix

`DataRegistry::Write`, case 3, at `0x1401C3C64`:

```
mov   rax, [rsi+8]
movzx ebx, byte [rax]          ; the byte, zero-extended
lea   rdx, [rsi+0x58]
mov   rcx, r13
call  Node::GetOrAdd
0x1401C3C77  mov dword [rax+0x20], 3     ->   mov dword [rax+0x20], 1
0x1401C3C7E  mov byte  [rax+0x2C], bl    ->   mov dword [rax+0x24], ebx
```

The node becomes an int node carrying the same value. The text writer prints
it as a number, the reader parses it as an int node, `GetAsNumber` returns it,
and `Read` case 3 narrows it back to the byte. A byte of 0xFF round-trips as
255 and narrows back to 0xFF. One 10-byte in-place edit, no code cave.

`scripts/Build-Directions.ps1` assembles the patch;
`patches/direction-save.patch.json` is the result.

## Why not vojin154's approach

Their DLL changes the two tile registrations from type 3 to type 1 at runtime.
That works for directions, but type 1 reads and writes four bytes through a
pointer to a one-byte field: `PrisonDir` at +0x40 aliases `StaffDir` at +0x41,
and `StaffDir` aliases the low byte of `SubsidenceStatus` at +0x44. It is
harmless in practice only because of the load order, and it leaves the colour
fields unfixed. Fixing the writer covers every byte field with no aliasing.

## Compatibility

Compatible with their DLL: it patches `0x1407B1846` and `0x1407B18B9`, which
this patch does not touch. With both installed the tile fields would be written
as ints by their change and everything else by ours; there is no conflict, but
the DLL is redundant.

Saves written by a patched game load fine in an unpatched game: the extra keys
are ordinary int values and the unpatched reader handles them (it just loses
them again on its next save).
