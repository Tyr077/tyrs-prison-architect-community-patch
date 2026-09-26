# Ghidra scripts

Headless helpers used to find and verify the patches. All take the output file
as the first argument; addresses are hex. Displacements (`DumpDisp`,
`DumpDispSites`, the `<disp>` of `DumpSpriteIdxCallers`) need a `0x` prefix, or
the value parses as decimal; `DumpAsmRange`, `DumpCallers` and `DumpImmRefs`
accept one; the other scripts want bare hex.

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
| `DumpDispSites` | `<ctx> 0x<disp>...` | every instruction using a displacement with `ctx` instructions of context; works for functions too big to decompile |
| `DumpCallers` | `<fn>...` | every call site of a function, then decompiles the target and its callers |
| `DumpDataRefs` | `<addr>...` | code references to a data address, plus the referencing functions |
| `DumpImmRefs` | `<imm>...` | instructions whose immediate equals a value (object type ids, magic numbers); noisy for values that are also common struct offsets |
| `DumpStringRefs` | `<str>...` | exact null-terminated string matches, references and referencers |
| `DumpSubstrRefs` | `<substr>...` | strings containing a substring (format strings, trailing spaces) |
| `DumpClass` | `<ClassName>...` | RTTI lookup: vtable methods and constructors of an MSVC class |
| `DumpSpriteIdxCallers` | `<fn> <disp>` | call sites of `fn` where `edx` came from `[reg+disp]` |
| `DumpAll` | `[<lo> <hi>]` | the first argument is a directory: decompiles every function into `decomp/<addr>.c` (one file per `0x10000` of entry addresses) and writes `index.tsv` (entry, name, size, callers, callees, referenced strings). Parallel; for grep and for matching functions between builds |
| `DumpRefs` | (none) | writes a TSV of what `DumpAll`'s index lacks: RTTI vtables with their slot functions, and code that takes a function's address without calling it; input for `scripts/match_builds.py` |
| `FindCaves` | `<minBytes>` | free `00`/`CC` runs in `.text` outside any function (the cave is full; see `docs/code-section.md`) |

Decompiler output is size-capped per function; for big functions use
`DumpAsmRange` or narrow the range.

## Fix-specific (kept for reference)

`DumpAsm`, `DumpContraband`, `DumpHandoff`, `DumpHandoff2`, `VerifyPatch`
belong to the gang hand-off investigation and hard-code its addresses.

## One-line runs
`scripts/Ghidra-Dump.ps1 <Script> <name> <args...>` runs a script against the analysed project and writes `analysis/<name>.txt`; add `-Exe <copy>` to run against a patched copy in a throwaway project instead. The facts these dumps establish go into `analysis/binary-facts.md`.

`-Build 2018` runs the script against the 2018 build's project instead and writes to `analysis/2018/`. `scripts/match_builds.py` (Python 3) pairs the functions of the two builds from their `DumpAll` indexes.

