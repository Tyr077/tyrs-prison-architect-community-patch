// DumpFuncRange.java <out> <hexLo> <hexHi> : decompile every function whose entry lies in [lo, hi).
import ghidra.app.script.GhidraScript; import ghidra.app.decompiler.*; import ghidra.program.model.listing.*; import java.io.*;
public class DumpFuncRange extends GhidraScript {
  public void run() throws Exception {
    String[] args = getScriptArgs(); PrintWriter out = new PrintWriter(new FileWriter(args[0]));
    long lo = Long.parseLong(args[1], 16), hi = Long.parseLong(args[2], 16);
    DecompInterface d = new DecompInterface(); d.setOptions(new DecompileOptions()); d.openProgram(currentProgram);
    FunctionIterator it = currentProgram.getFunctionManager().getFunctions(toAddr(lo), true);
    while (it.hasNext()) { Function f = it.next(); if (f.getEntryPoint().getOffset() >= hi) break;
      out.println("\n---- " + f.getName() + " @ " + f.getEntryPoint() + " size=" + f.getBody().getNumAddresses() + " ----");
      StringBuilder cs = new StringBuilder(); for (Function c : f.getCallingFunctions(monitor)) cs.append(c.getName()).append(' '); out.println("// callers: " + cs);
      DecompileResults r = d.decompileFunction(f, 180, monitor); out.println(r.decompileCompleted() ? r.getDecompiledFunction().getC() : "// FAILED"); out.flush(); }
    d.dispose(); out.close(); println("DumpFuncRange wrote " + args[0]); }
}
