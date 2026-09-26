// DumpAll.java <outDir> [hexLo hexHi] : decompile every function (optionally only entries in [lo, hi)) for grep.
//   <outDir>/decomp/<addr & ~0xFFFF>.c   one file per 0x10000 of entry addresses, functions in address order
//   <outDir>/index.tsv                   entry, name, size, callers, callees, referenced strings (" | " separated)
// The string column is the main evidence for matching a function between builds (scripts/match_builds.py).
import ghidra.app.script.GhidraScript;
import ghidra.app.decompiler.*;
import ghidra.app.decompiler.parallel.*;
import ghidra.program.model.address.*;
import ghidra.program.model.listing.*;
import ghidra.program.model.symbol.*;
import ghidra.util.task.TaskMonitor;
import java.io.*;
import java.util.*;

public class DumpAll extends GhidraScript {
    static final int BATCH = 1500, TIMEOUT = 120, MAX_STR = 120;

    public void run() throws Exception {
        String[] args = getScriptArgs();
        File outDir = new File(args[0]); File decompDir = new File(outDir, "decomp"); decompDir.mkdirs();
        long lo = args.length > 2 ? Long.parseLong(args[1], 16) : 0, hi = args.length > 2 ? Long.parseLong(args[2], 16) : Long.MAX_VALUE;

        List<Function> all = new ArrayList<>();
        for (Function f : currentProgram.getFunctionManager().getFunctions(true)) {
            long a = f.getEntryPoint().getOffset();
            if (a >= lo && a < hi && !f.isExternal() && !f.isThunk()) all.add(f);
        }
        println("DumpAll: " + all.size() + " functions");

        DecompilerCallback<String[]> cb = new DecompilerCallback<String[]>(currentProgram, new DecompileConfigurer() {
            public void configure(DecompInterface d) { d.setOptions(new DecompileOptions()); d.toggleSyntaxTree(false); }
        }) {
            public String[] process(DecompileResults r, TaskMonitor m) {
                Function f = r.getFunction();
                String c = r.decompileCompleted() ? r.getDecompiledFunction().getC() : "// DECOMPILE FAILED: " + r.getErrorMessage() + "\n";
                return new String[] { f.getEntryPoint().toString(), c };
            }
        };
        cb.setTimeout(TIMEOUT);

        PrintWriter index = new PrintWriter(new FileWriter(new File(outDir, "index.tsv")));
        index.println("entry\tname\tsize\tcallers\tcallees\tstrings");
        long curChunk = -1; PrintWriter out = null; int done = 0, failed = 0;
        for (int i = 0; i < all.size() && !monitor.isCancelled(); i += BATCH) {
            List<Function> batch = all.subList(i, Math.min(i + BATCH, all.size()));
            Map<String, String> code = new HashMap<>();
            for (String[] r : ParallelDecompiler.decompileFunctions(cb, batch, monitor)) if (r != null) code.put(r[0], r[1]);
            for (Function f : batch) {
                long a = f.getEntryPoint().getOffset(), chunk = a & ~0xFFFFL;
                if (chunk != curChunk) { if (out != null) out.close(); out = new PrintWriter(new FileWriter(new File(decompDir, Long.toHexString(chunk) + ".c"))); curChunk = chunk; }
                StringBuilder callers = new StringBuilder(), callees = new StringBuilder();
                for (Function c : f.getCallingFunctions(monitor)) callers.append(c.getName()).append(' ');
                for (Function c : f.getCalledFunctions(monitor)) callees.append(c.getName()).append(' ');
                String strs = strings(f);
                String c = code.get(f.getEntryPoint().toString());
                if (c == null || c.startsWith("// DECOMPILE FAILED")) failed++;
                out.println("\n---- " + f.getName() + " @ " + f.getEntryPoint() + " size=" + f.getBody().getNumAddresses() + " ----");
                out.println("// callers: " + callers);
                if (!strs.isEmpty()) out.println("// strings: " + strs);
                out.println(c == null ? "// DECOMPILE FAILED: no result\n" : c);
                index.println(f.getEntryPoint() + "\t" + f.getName() + "\t" + f.getBody().getNumAddresses() + "\t" + callers.toString().trim() + "\t" + callees.toString().trim() + "\t" + strs);
            }
            done += batch.size(); index.flush(); out.flush();
            println("DumpAll: " + done + " / " + all.size());
        }
        if (out != null) out.close(); index.close(); cb.dispose();
        println("DumpAll wrote " + outDir + " (" + done + " functions, " + failed + " failed)");
    }

    // Strings referenced from the function body, in address order, without duplicates.
    String strings(Function f) {
        LinkedHashSet<String> seen = new LinkedHashSet<>();
        Listing listing = currentProgram.getListing();
        InstructionIterator it = listing.getInstructions(f.getBody(), true);
        while (it.hasNext()) for (Reference r : it.next().getReferencesFrom()) {
            if (!r.getToAddress().isMemoryAddress()) continue;
            Data d = listing.getDataAt(r.getToAddress());
            if (d == null || !d.hasStringValue()) continue;
            String s = String.valueOf(d.getValue()).replace('\t', ' ').replace('\r', ' ').replace('\n', ' ');
            seen.add(s.length() > MAX_STR ? s.substring(0, MAX_STR) : s);
        }
        return String.join(" | ", seen);
    }
}
