// DumpDisp.java <out> <hexDisp>... : list functions using each displacement; decompile those using ALL of them (size-capped).
import ghidra.app.script.GhidraScript; import ghidra.app.decompiler.*; import ghidra.program.model.listing.*; import ghidra.program.model.scalar.Scalar; import java.io.*; import java.util.*;
public class DumpDisp extends GhidraScript {
  public void run() throws Exception {
    String[] args = getScriptArgs(); PrintWriter out = new PrintWriter(new FileWriter(args[0]));
    List<Long> want = new ArrayList<>(); for (int i = 1; i < args.length; i++) want.add(Long.decode(args[i]));
    Map<Function, Set<Long>> hits = new LinkedHashMap<>();
    InstructionIterator it = currentProgram.getListing().getInstructions(true);
    while (it.hasNext()) { Instruction ins = it.next();
      for (int i = 0; i < ins.getNumOperands(); i++) for (Object o : ins.getOpObjects(i)) if (o instanceof Scalar) { long v = ((Scalar) o).getUnsignedValue();
        if (want.contains(v)) { Function f = getFunctionContaining(ins.getAddress()); if (f != null) hits.computeIfAbsent(f, k -> new TreeSet<>()).add(v); } } }
    for (long w : want) { out.println("== functions using 0x" + Long.toHexString(w) + ":"); for (Map.Entry<Function, Set<Long>> e : hits.entrySet()) if (e.getValue().contains(w)) out.println("   " + e.getKey().getName() + " @ " + e.getKey().getEntryPoint() + " size=" + e.getKey().getBody().getNumAddresses() + "  uses " + e.getValue().size() + "/" + want.size()); }
    DecompInterface d = new DecompInterface(); d.setOptions(new DecompileOptions()); d.openProgram(currentProgram);
    for (Map.Entry<Function, Set<Long>> e : hits.entrySet()) if (e.getValue().size() == want.size()) { Function f = e.getKey();
      out.println("\n---- " + f.getName() + " @ " + f.getEntryPoint() + "  [all disps]  size=" + f.getBody().getNumAddresses() + " ----");
      StringBuilder cs = new StringBuilder(); for (Function c : f.getCallingFunctions(monitor)) cs.append(c.getName()).append(' '); out.println("// callers: " + cs);
      if (f.getBody().getNumAddresses() > 14000) { out.println("// skipped: too big"); continue; }
      DecompileResults r = d.decompileFunction(f, 180, monitor); out.println(r.decompileCompleted() ? r.getDecompiledFunction().getC() : "// FAILED"); out.flush(); }
    d.dispose(); out.close(); println("DumpDisp wrote " + args[0]); }
}
