// Decompiles every function anchored to ContrabandSystem in Prison Architect64.exe:
// the vtable methods, the constructor (xref to vtable), the save/load serializer
// (xrefs to field-name strings), plus one level of callers and callees of each.
import ghidra.app.script.GhidraScript;
import ghidra.app.decompiler.*;
import ghidra.program.model.address.*;
import ghidra.program.model.listing.*;
import ghidra.program.model.symbol.*;
import java.io.*;
import java.util.*;

public class DumpContraband extends GhidraScript {
    DecompInterface decomp;
    PrintWriter out;
    Set<Long> done = new HashSet<>();

    static final long VTABLE = 0x140AF3D38L;
    static final long[] VT_FUNCS = { 0x1404F7020L, 0x140507160L, 0x1405076E0L };
    static final long[] STRINGS = { 0x140AF3928L, 0x140AF3970L, 0x140AF3980L, 0x140AF3A00L };

    public void run() throws Exception {
        String[] args = getScriptArgs();
        String outPath = args.length > 0 ? args[0] : "D:/projects/prison-architect-handoff-fix/decomp.txt";
        out = new PrintWriter(new FileWriter(outPath));
        decomp = new DecompInterface();
        DecompileOptions opts = new DecompileOptions();
        decomp.setOptions(opts);
        decomp.openProgram(currentProgram);

        out.println("==== ContrabandSystem vtable methods ====");
        List<Function> core = new ArrayList<>();
        for (long a : VT_FUNCS) { Function f = getFunctionAt(toAddr(a)); if (f != null) { core.add(f); dump(f, "vtable"); } else out.println("no function at " + Long.toHexString(a)); }

        out.println("\n==== xrefs to vtable (constructor) ====");
        for (Reference r : getReferencesTo(toAddr(VTABLE))) { Function f = getFunctionContaining(r.getFromAddress()); if (f != null) { core.add(f); dump(f, "vtable-xref from " + r.getFromAddress()); } }

        out.println("\n==== xrefs to field-name strings (serializer) ====");
        for (long s : STRINGS) for (Reference r : getReferencesTo(toAddr(s))) { Function f = getFunctionContaining(r.getFromAddress()); if (f != null) { core.add(f); dump(f, "string " + Long.toHexString(s) + " from " + r.getFromAddress()); } else out.println("string " + Long.toHexString(s) + " ref from " + r.getFromAddress() + " not in a function"); }

        out.println("\n==== one level of callers ====");
        for (Function f : new ArrayList<>(core)) for (Function c : f.getCallingFunctions(monitor)) dump(c, "caller of " + f.getName());

        out.println("\n==== one level of callees of vtable methods ====");
        for (long a : VT_FUNCS) { Function f = getFunctionAt(toAddr(a)); if (f == null) continue; for (Function c : f.getCalledFunctions(monitor)) dump(c, "callee of " + f.getName()); }

        out.close();
        decomp.dispose();
        println("DumpContraband wrote " + outPath);
    }

    void dump(Function f, String why) {
        if (!done.add(f.getEntryPoint().getOffset())) return;
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
