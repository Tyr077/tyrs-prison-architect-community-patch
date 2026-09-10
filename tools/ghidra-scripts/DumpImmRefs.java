// DumpImmRefs.java <out> <hexImm>... : find every instruction whose scalar operand equals one of the given
// immediates, list them by containing function, and decompile those functions (each once, size-capped).
import ghidra.app.script.GhidraScript;
import ghidra.app.decompiler.*;
import ghidra.program.model.listing.*;
import ghidra.program.model.scalar.Scalar;
import java.io.*;
import java.util.*;

public class DumpImmRefs extends GhidraScript {
  public void run() throws Exception {
    String[] args = getScriptArgs(); PrintWriter out = new PrintWriter(new FileWriter(args[0]));
    Set<Long> want = new HashSet<>(); for (int i = 1; i < args.length; i++) want.add(Long.parseLong(args[i].replace("0x",""), 16));
    Map<Function, List<String>> hits = new LinkedHashMap<>(); int orphan = 0;
    for (Instruction ins : currentProgram.getListing().getInstructions(true)) {
      for (int op = 0; op < ins.getNumOperands(); op++) for (Object o : ins.getOpObjects(op)) {
        if (o instanceof Scalar) { long v = ((Scalar) o).getUnsignedValue();
          if (want.contains(v) || want.contains(((Scalar) o).getSignedValue())) {
            Function f = getFunctionContaining(ins.getAddress());
            if (f == null) { orphan++; continue; }
            hits.computeIfAbsent(f, k -> new ArrayList<>()).add(ins.getAddress() + "  " + ins);
          }
        }
      }
    }
    out.println("==== " + hits.size() + " functions, " + orphan + " hits outside functions ====");
    for (Map.Entry<Function, List<String>> e : hits.entrySet()) { out.println(e.getKey().getName() + " @ " + e.getKey().getEntryPoint()); for (String s : e.getValue()) out.println("    " + s); }
    DecompInterface d = new DecompInterface(); d.openProgram(currentProgram);
    for (Function f : hits.keySet()) {
      out.println("---- " + f.getName() + " @ " + f.getEntryPoint() + " size=" + f.getBody().getNumAddresses() + " ----");
      if (f.getBody().getNumAddresses() > 40000) { out.println("(too big, skipped)"); continue; }
      DecompileResults r = d.decompileFunction(f, 120, monitor);
      out.println(r.getDecompiledFunction() != null ? r.getDecompiledFunction().getC() : "(decompile failed)");
    }
    out.close();
  }
}
