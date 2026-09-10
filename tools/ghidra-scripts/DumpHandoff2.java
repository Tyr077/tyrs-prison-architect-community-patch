// Second pass: hand-off helpers, ContrabandSystem this-relative field users,
// and every place that tests or sets prisoner misbehaviour state 10 (ContrabandHandOff).
import ghidra.app.script.GhidraScript;
import ghidra.app.decompiler.*;
import ghidra.program.model.address.*;
import ghidra.program.model.listing.*;
import ghidra.program.model.scalar.Scalar;
import java.io.*;
import java.util.*;

public class DumpHandoff2 extends GhidraScript {
    DecompInterface decomp; PrintWriter out; Set<Long> done = new HashSet<>();
    static final long[] HELPERS = { 0x140508ce0L, 0x1405056c0L, 0x1405c2ff0L, 0x1406aed00L, 0x1407bea70L,
                                    0x140532430L, 0x1401c9710L, 0x14066c170L, 0x1405d7ed0L, 0x140505dd0L, 0x1407badc0L };
    static final long CLUSTER_LO = 0x1404f5000L, CLUSTER_HI = 0x140510000L;
    static final long[] THIS_OFFS = { 0x184L, 0x188L, 0x18cL, 0x190L, 0x194L, 0x198L, 0x19cL };

    public void run() throws Exception {
        String[] args = getScriptArgs();
        String outPath = args.length > 0 ? args[0] : "D:/projects/prison-architect-handoff-fix/decomp3.txt";
        out = new PrintWriter(new FileWriter(outPath));
        decomp = new DecompInterface(); decomp.setOptions(new DecompileOptions()); decomp.openProgram(currentProgram);

        out.println("==== helpers ====");
        for (long a : HELPERS) { Function f = getFunctionAt(toAddr(a)); if (f != null) dump(f, "helper"); else out.println("no function at " + Long.toHexString(a)); }

        out.println("\n==== ContrabandSystem cluster functions using this-relative hand-off fields ====");
        Map<Function, Set<Long>> clusterHits = new LinkedHashMap<>();
        Map<Function, List<String>> state10 = new LinkedHashMap<>();
        Set<Long> offs = new HashSet<>(); for (long o : THIS_OFFS) offs.add(o);
        InstructionIterator it = currentProgram.getListing().getInstructions(true);
        while (it.hasNext()) {
            Instruction ins = it.next();
            long addr = ins.getAddress().getOffset();
            boolean hasA2c = false, hasTen = false; Set<Long> found = null;
            for (int i = 0; i < ins.getNumOperands(); i++) for (Object o : ins.getOpObjects(i)) if (o instanceof Scalar) {
                long v = ((Scalar) o).getUnsignedValue();
                if (v == 0xa2cL) hasA2c = true;
                if (v == 0xaL) hasTen = true;
                if (addr >= CLUSTER_LO && addr < CLUSTER_HI && offs.contains(v)) { if (found == null) found = new HashSet<>(); found.add(v); }
            }
            if (found != null) { Function f = getFunctionContaining(ins.getAddress()); if (f != null) clusterHits.computeIfAbsent(f, k -> new TreeSet<>()).addAll(found); }
            if (hasA2c && hasTen) { Function f = getFunctionContaining(ins.getAddress()); if (f != null) state10.computeIfAbsent(f, k -> new ArrayList<>()).add(ins.getAddress() + ": " + ins); }
        }
        for (Map.Entry<Function, Set<Long>> e : clusterHits.entrySet()) {
            StringBuilder sb = new StringBuilder(); for (long v : e.getValue()) sb.append("0x").append(Long.toHexString(v)).append(' ');
            out.println("  " + e.getKey().getName() + " @ " + e.getKey().getEntryPoint() + " size=" + e.getKey().getBody().getNumAddresses() + "  offs: " + sb);
        }
        for (Function f : clusterHits.keySet()) dump(f, "cluster field user");

        out.println("\n==== instructions touching +0xa2c with immediate 10 (state ContrabandHandOff) ====");
        for (Map.Entry<Function, List<String>> e : state10.entrySet()) {
            out.println("  " + e.getKey().getName() + " @ " + e.getKey().getEntryPoint() + " size=" + e.getKey().getBody().getNumAddresses());
            for (String s : e.getValue()) out.println("      " + s);
        }
        for (Function f : state10.keySet()) if (f.getBody().getNumAddresses() < 12000) dump(f, "state10 user"); else out.println("// skipped (too big): " + f.getName());

        out.close(); decomp.dispose(); println("DumpHandoff2 wrote " + outPath);
    }
    void dump(Function f, String why) {
        if (!done.add(f.getEntryPoint().getOffset())) { out.println("// (already dumped) " + f.getName() + " [" + why + "]"); return; }
        out.println("\n---- " + f.getName() + " @ " + f.getEntryPoint() + "  [" + why + "]  size=" + f.getBody().getNumAddresses() + " ----");
        StringBuilder cs = new StringBuilder(); for (Function c : f.getCallingFunctions(monitor)) cs.append(c.getName()).append("@").append(c.getEntryPoint()).append(' ');
        out.println("// callers: " + cs);
        DecompileResults r = decomp.decompileFunction(f, 180, monitor);
        if (r != null && r.decompileCompleted()) out.println(r.getDecompiledFunction().getC()); else out.println("// DECOMPILE FAILED");
        out.flush();
    }
}
