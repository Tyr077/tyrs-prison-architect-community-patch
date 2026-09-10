// Finds the non-virtual hand-off logic: functions that reference the hand-off
// strings/settings keys, and functions that address the ContrabandSystem
// fields through the World object (World + 0x21A0 + field).
import ghidra.app.script.GhidraScript;
import ghidra.app.decompiler.*;
import ghidra.program.model.address.*;
import ghidra.program.model.listing.*;
import ghidra.program.model.mem.*;
import ghidra.program.model.scalar.Scalar;
import ghidra.program.model.symbol.*;
import java.io.*;
import java.util.*;

public class DumpHandoff extends GhidraScript {
    DecompInterface decomp;
    PrintWriter out;
    Set<Long> done = new HashSet<>();

    static final String[] STRINGS = {
        "ContrabandHandOff", "HandOffGangMember", "HandOffGuard",
        "Contraband Hand-Off Duration (Minutes)", "Minimum Detection Distance during Hand-Off",
        "Contraband Pick Up Duration (Minutes)", "Active Bribe Effect Time (Hrs)",
        "TargetBribeGuardId", "TriggerBribe", "ForceBribeDebug", "Corrupted", "BribedTime_",
        "CrookedGuardsSettings", "Crooked Guards Settings - Kimber", "LastCorruptionCheckTime"
    };
    // World-relative displacements: 0x21A0 = ContrabandSystem, then + field offset
    static final long[] DISPS = { 0x21A0L, 0x2324L, 0x2328L, 0x232CL, 0x2330L, 0x2334L, 0x2338L, 0x233CL };

    public void run() throws Exception {
        String[] args = getScriptArgs();
        String outPath = args.length > 0 ? args[0] : "D:/projects/prison-architect-handoff-fix/decomp2.txt";
        out = new PrintWriter(new FileWriter(outPath));
        decomp = new DecompInterface();
        decomp.setOptions(new DecompileOptions());
        decomp.openProgram(currentProgram);
        Memory mem = currentProgram.getMemory();

        out.println("==== string references ====");
        Map<String, List<Function>> byString = new LinkedHashMap<>();
        for (String s : STRINGS) {
            byte[] pat = (s + "\0").getBytes("US-ASCII");
            Address a = mem.getMinAddress();
            List<Function> fs = new ArrayList<>();
            while (a != null) {
                Address hit = mem.findBytes(a, pat, null, true, monitor);
                if (hit == null) break;
                int nref = 0;
                for (Reference r : getReferencesTo(hit)) {
                    nref++;
                    Function f = getFunctionContaining(r.getFromAddress());
                    if (f != null && !fs.contains(f)) fs.add(f);
                }
                // strings referenced via a pointer table: check refs to the hit from data
                out.println("  \"" + s + "\" @ " + hit + "  refs=" + nref);
                a = hit.add(1);
            }
            byString.put(s, fs);
        }
        for (Map.Entry<String, List<Function>> e : byString.entrySet())
            for (Function f : e.getValue()) dump(f, "string \"" + e.getKey() + "\"");

        out.println("\n==== World-relative displacement references ====");
        Map<Long, Set<Function>> byDisp = new TreeMap<>();
        for (long d : DISPS) byDisp.put(d, new LinkedHashSet<>());
        InstructionIterator it = currentProgram.getListing().getInstructions(true);
        while (it.hasNext()) {
            Instruction ins = it.next();
            int n = ins.getNumOperands();
            for (int i = 0; i < n; i++) {
                for (Object o : ins.getOpObjects(i)) {
                    if (o instanceof Scalar) {
                        long v = ((Scalar) o).getUnsignedValue();
                        if (byDisp.containsKey(v)) {
                            Function f = getFunctionContaining(ins.getAddress());
                            if (f != null) byDisp.get(v).add(f);
                        }
                    }
                }
            }
        }
        for (Map.Entry<Long, Set<Function>> e : byDisp.entrySet()) {
            out.println("  disp 0x" + Long.toHexString(e.getKey()) + ": " + e.getValue().size() + " function(s)");
            for (Function f : e.getValue()) out.println("      " + f.getName() + " @ " + f.getEntryPoint() + " size=" + f.getBody().getNumAddresses());
        }
        for (Map.Entry<Long, Set<Function>> e : byDisp.entrySet())
            for (Function f : e.getValue()) if (f.getBody().getNumAddresses() < 20000) dump(f, "disp 0x" + Long.toHexString(e.getKey()));

        out.close();
        decomp.dispose();
        println("DumpHandoff wrote " + outPath);
    }

    void dump(Function f, String why) {
        if (!done.add(f.getEntryPoint().getOffset())) { out.println("// (already dumped) " + f.getName() + " [" + why + "]"); return; }
        out.println("\n---- " + f.getName() + " @ " + f.getEntryPoint() + "  [" + why + "]  size=" + f.getBody().getNumAddresses() + " ----");
        StringBuilder cs = new StringBuilder();
        for (Function c : f.getCallingFunctions(monitor)) cs.append(c.getName()).append("@").append(c.getEntryPoint()).append(" ");
        out.println("// callers: " + cs);
        DecompileResults r = decomp.decompileFunction(f, 180, monitor);
        if (r != null && r.decompileCompleted()) out.println(r.getDecompiledFunction().getC());
        else out.println("// DECOMPILE FAILED: " + (r == null ? "null" : r.getErrorMessage()));
        out.flush();
    }
}
