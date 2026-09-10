// Generic: for each string given as an argument (after the output path), find every occurrence
// in memory, list references, and decompile the referencing functions (size-capped).
//   analyzeHeadless ... -postScript DumpStringRefs.java <out.txt> <str1> <str2> ...
import ghidra.app.script.GhidraScript;
import ghidra.app.decompiler.*;
import ghidra.program.model.address.*;
import ghidra.program.model.listing.*;
import ghidra.program.model.mem.*;
import ghidra.program.model.symbol.*;
import java.io.*;
import java.util.*;

public class DumpStringRefs extends GhidraScript {
    DecompInterface decomp; PrintWriter out; Set<Long> done = new HashSet<>();
    static final int MAX_FUNC_SIZE = 30000;

    public void run() throws Exception {
        String[] args = getScriptArgs();
        out = new PrintWriter(new FileWriter(args[0]));
        decomp = new DecompInterface(); decomp.setOptions(new DecompileOptions()); decomp.openProgram(currentProgram);
        Memory mem = currentProgram.getMemory();
        Map<String, List<Function>> byString = new LinkedHashMap<>();
        for (int ai = 1; ai < args.length; ai++) {
            String s = args[ai];
            byte[] pat = (s + "\0").getBytes("US-ASCII");
            Address a = mem.getMinAddress();
            List<Function> fs = new ArrayList<>();
            while (a != null) {
                Address hit = mem.findBytes(a, pat, null, true, monitor);
                if (hit == null) break;
                // only count hits that start a string (previous byte is NUL or non-printable)
                byte prev = hit.getOffset() > mem.getMinAddress().getOffset() ? mem.getByte(hit.subtract(1)) : 0;
                boolean startsString = prev == 0 || prev < 0x20;
                int nref = 0;
                if (startsString) for (Reference r : getReferencesTo(hit)) {
                    nref++;
                    Function f = getFunctionContaining(r.getFromAddress());
                    if (f != null && !fs.contains(f)) fs.add(f);
                    else if (f == null) out.println("  (ref from " + r.getFromAddress() + " outside any function)");
                }
                out.println("\"" + s + "\" @ " + hit + (startsString ? "" : " (mid-string)") + "  refs=" + nref);
                a = hit.add(1);
            }
            byString.put(s, fs);
        }
        for (Map.Entry<String, List<Function>> e : byString.entrySet())
            for (Function f : e.getValue()) dump(f, "string \"" + e.getKey() + "\"");
        out.close(); decomp.dispose(); println("DumpStringRefs wrote " + args[0]);
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
