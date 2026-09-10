# Ghidra scripts

Headless helpers used to find and verify the patches. All take the output file
as the first argument; addresses are hex (prefix displacements with `0x` for
`DumpDisp`, otherwise they parse as decimal).

Run from PowerShell with `JAVA_HOME` set to a JDK 21:

```
& "$Ghidra\support\analyzeHeadless.bat" <projectDir> <projectName> -process "Prison Architect64.exe" -noanalysis `
    -scriptPath tools\ghidra-scripts -postScript <Script>.java <out.txt> <args...>
```

For a patched copy, use a throwaway project instead:
`analyzeHeadless <scratch>\ghidra-verify Verify -import copy.exe -noanalysis -deleteProject -postScript ...`
(add a `disassemble()` call before listing when the import was not analysed).

## Generic

| script | args | use |
|---|---|---|
| `DumpFuncs` | `<addr>...` | decompile the listed functions |
| `DumpFuncRange` | `<lo> <hi>` | decompile every function whose entry lies in `[lo, hi)` |
| `DumpAsmRange` | `<lo> <hi> [...]` | disassembly with bytes for address ranges (patch verification) |
| `DumpDisp` | `0x<disp>...` | functions using each displacement; decompile those using all of them |
| `DumpDataRefs` | `<addr>...` | code references to a data address, plus the referencing functions |
| `DumpStringRefs` | `<str>...` | exact null-terminated string matches, references and referencers |
| `DumpSubstrRefs` | `<substr>...` | strings containing a substring (format strings, trailing spaces) |
| `DumpClass` | `<ClassName>...` | RTTI lookup: vtable methods and constructors of an MSVC class |
| `DumpSpriteIdxCallers` | `<fn> <disp>` | call sites of `fn` where `edx` came from `[reg+disp]` |
| `FindCaves` | `<minBytes>` | free `00`/`CC` runs in `.text` outside any function (the cave is full; see `docs/code-section.md`) |

Decompiler output is size-capped per function; for big functions use
`DumpAsmRange` or narrow the range.

## Fix-specific (kept for reference)

`DumpAsm`, `DumpContraband`, `DumpHandoff`, `DumpHandoff2`, `VerifyPatch`
belong to the gang hand-off investigation and hard-code its addresses.
