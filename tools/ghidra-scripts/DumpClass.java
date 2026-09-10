// Generic: for each MSVC class name given as an argument (after the output path), locate its RTTI
// type descriptor, complete object locator and vtable, then decompile every virtual method plus the
// constructor(s) that reference the vtable.
//   analyzeHeadless ... -postScript DumpClass.java <out.txt> <ClassName> ...
import ghidra.app.script.GhidraScript;
import ghidra.app.decompiler.*;
import ghidra.program.model.address.*;
import ghidra.program.model.listing.*;
import ghidra.program.model.mem.*;
import ghidra.program.model.symbol.*;
import java.io.*;
import java.util.*;

public class DumpClass extends GhidraScript {
    DecompInterface decomp; PrintWriter out; Set<Long> done = new HashSet<>();
    static final int MAX_FUNC_SIZE = 30000;

    public void run() throws Exception {
        String[] args = getScriptArgs();
        out = new PrintWriter(new FileWriter(args[0]));
        decomp = new DecompInterface(); decomp.setOptions(new DecompileOptions()); decomp.openProgram(currentProgram);
        Memory mem = currentProgram.getMemory();
        long imageBase = currentProgram.getImageBase().getOffset();
        MemoryBlock rdata = mem.getBlock(".rdata");
        for (int ai = 1; ai < args.length; ai++) {
            String cls = args[ai];
            out.println("\n==== class " + cls + " ====");
            byte[] pat = (".?AV" + cls + "@@\0").getBytes("US-ASCII");
            Address nameAddr = mem.findBytes(mem.getMinAddress(), pat, null, true, monitor);
            if (nameAddr == null) { out.println("type name not found"); continue; }
            long tdRva = nameAddr.getOffset() - 16 - imageBase;
            out.println("TypeDescriptor RVA 0x" + Long.toHexString(tdRva));
            // find COL: dword at +12 == tdRva, signature dword == 1
            byte[] tdBytes = new byte[] { (byte) tdRva, (byte) (tdRva >> 8), (byte) (tdRva >> 16), (byte) (tdRva >> 24) };
            Address a = rdata.getStart();
            List<Address> vtables = new ArrayList<>();
            while (a != null && a.compareTo(rdata.getEnd()) < 0) {
                Address hit = mem.findBytes(a, tdBytes, null, true, monitor);
                if (hit == null || hit.compareTo(rdata.getEnd()) > 0) break;
                Address col = hit.subtract(12);
                if (col.compareTo(rdata.getStart()) >= 0 && mem.getInt(col) == 1) {
                    long colVa = col.getOffset();
                    byte[] colBytes = new byte[8]; for (int i = 0; i < 8; i++) colBytes[i] = (byte) (colVa >> (8 * i));
                    Address p = rdata.getStart();
                    while (p != null) {
                        Address ph = mem.findBytes(p, colBytes, null, true, monitor);
                        if (ph == null || ph.compareTo(rdata.getEnd()) > 0) break;
                        vtables.add(ph.add(8));
                        p = ph.add(1);
                    }
                }
                a = hit.add(1);
            }
            for (Address vt : vtables) {
                out.println("VTABLE @ " + vt);
                List<Function> methods = new ArrayList<>();
                Address p = vt;
                for (int i = 0; i < 80; i++) {
                    long fn = mem.getLong(p);
                    if (fn < imageBase || fn > imageBase + 0x2000000L) break;
                    Function f = getFunctionAt(toAddr(fn));
                    out.println("  [" + i + "] " + toAddr(fn) + (f == null ? " (no function)" : " " + f.getName() + " size=" + f.getBody().getNumAddresses()));
                    if (f != null) methods.add(f);
                    p = p.add(8);
                }
                for (Reference r : getReferencesTo(vt)) { Function f = getFunctionContaining(r.getFromAddress()); if (f != null) dump(f, cls + " ctor/dtor (vtable xref)"); }
                for (Function f : methods) dump(f, cls + " virtual");
            }
        }
        out.close(); decomp.dispose(); println("DumpClass wrote " + args[0]);
    }

    void dump(Function f, String why) {
        if (!done.add(f.getEntryPoint().getOffset())) { out.println("// (already dumped) " + f.getName() + " [" + why + "]"); return; }
        out.println("\n---- " + f.getName() + " @ " + f.getEntryPoint() + "  [" + why + "]  size=" + f.getBody().getNumAddresses() + " ----");
        StringBuilder cs = new StringBuilder(); for (Function c : f.getCallingFunctions(monitor)) cs.append(c.getName()).append("@").append(c.getEntryPoint()).append(' ');
        out.println("// callers: " + cs);
        if (f.getBody().getNumAddresses() > MAX_FUNC_SIZE) { out.println("// skipped: too big"); return; }
        DecompileResults r = decomp.decompileFunction(f, 180, monitor);
        out.println(r != null && r.decompileCompleted() ? r.getDecompiledFunction().getC() : "// DECOMPILE FAILED");
        out.flush();
    }
}
