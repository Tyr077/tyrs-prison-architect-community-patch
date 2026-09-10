// DumpDataRefs.java <out> <hexAddr>... : for each data address, list every code reference to it and
// decompile the referencing functions (each once, size-capped). Use for global objects/strings/tables.
import ghidra.app.script.GhidraScript; import ghidra.app.decompiler.*; import ghidra.program.model.listing.*; import ghidra.program.model.symbol.*; import java.io.*; import java.util.*;
public class DumpDataRefs extends GhidraScript {
  public void run() throws Exception {
    String[] args = getScriptArgs(); PrintWriter out = new PrintWriter(new FileWriter(args[0]));
    DecompInterface d = new DecompInterface(); d.setOptions(new DecompileOptions()); d.openProgram(currentProgram);
    ReferenceManager rm = currentProgram.getReferenceManager(); Set<Long> done = new HashSet<>();
    for (int i = 1; i < args.length; i++) { long a = Long.parseLong(args[i], 16); out.println("\n==== data " + args[i] + " ====");
      List<Function> fs = new ArrayList<>();
      for (Reference r : rm.getReferencesTo(toAddr(a))) { Function f = getFunctionContaining(r.getFromAddress()); out.println("ref from " + r.getFromAddress() + " in " + (f == null ? "?" : f.getName())); if (f != null && done.add(f.getEntryPoint().getOffset())) fs.add(f); }
      for (Function f : fs) { if (f.getBody().getNumAddresses() > 40000) { out.println("---- " + f.getName() + " too big ----"); continue; }
        out.println("\n---- " + f.getName() + " @ " + f.getEntryPoint() + " size=" + f.getBody().getNumAddresses() + " ----");
        DecompileResults r = d.decompileFunction(f, 240, monitor); out.println(r.decompileCompleted() ? r.getDecompiledFunction().getC() : "// FAILED"); out.flush(); } }
    d.dispose(); out.close(); println("DumpDataRefs wrote " + args[0]); }
}
