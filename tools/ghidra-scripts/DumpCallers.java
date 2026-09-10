// DumpCallers.java <out> <hexFn>... : list every call site of each function and decompile the calling
// functions (each once, size-capped). Also decompiles the target itself.
import ghidra.app.script.GhidraScript;
import ghidra.app.decompiler.*;
import ghidra.program.model.address.Address;
import ghidra.program.model.listing.Function;
import ghidra.program.model.symbol.*;
import java.io.*;
import java.util.*;

public class DumpCallers extends GhidraScript {
  public void run() throws Exception {
    String[] args = getScriptArgs(); PrintWriter out = new PrintWriter(new FileWriter(args[0]));
    DecompInterface d = new DecompInterface(); d.openProgram(currentProgram);
    Set<Long> done = new HashSet<>();
    for (int i = 1; i < args.length; i++) {
      Address fn = toAddr(Long.parseLong(args[i].replace("0x",""), 16));
      Function f = getFunctionAt(fn);
      out.println("==== target " + fn + (f == null ? " (no function)" : " " + f.getName() + " size=" + f.getBody().getNumAddresses()) + " ====");
      if (f != null && done.add(fn.getOffset())) decomp(d, f, out);
      List<Function> callers = new ArrayList<>();
      for (Reference r : getReferencesTo(fn)) {
        Function c = getFunctionContaining(r.getFromAddress());
        out.println("  ref from " + r.getFromAddress() + " type=" + r.getReferenceType() + (c == null ? "" : " in " + c.getName()));
        if (c != null && !callers.contains(c)) callers.add(c);
      }
      for (Function c : callers) if (done.add(c.getEntryPoint().getOffset())) decomp(d, c, out);
    }
    out.close();
  }
  void decomp(DecompInterface d, Function f, PrintWriter out) {
    out.println("---- " + f.getName() + " @ " + f.getEntryPoint() + " size=" + f.getBody().getNumAddresses() + " ----");
    if (f.getBody().getNumAddresses() > 40000) { out.println("(too big, skipped)"); return; }
    DecompileResults r = d.decompileFunction(f, 120, monitor);
    out.println(r.getDecompiledFunction() != null ? r.getDecompiledFunction().getC() : "(decompile failed)");
  }
}
