// DumpFuncs.java <out> <hexAddr>... : decompile the listed functions.
import ghidra.app.script.GhidraScript; import ghidra.app.decompiler.*; import ghidra.program.model.listing.*; import java.io.*;
public class DumpFuncs extends GhidraScript {
  public void run() throws Exception {
    String[] args = getScriptArgs(); PrintWriter out = new PrintWriter(new FileWriter(args[0]));
    DecompInterface d = new DecompInterface(); d.setOptions(new DecompileOptions()); d.openProgram(currentProgram);
    for (int i = 1; i < args.length; i++) { Function f = getFunctionContaining(toAddr(Long.parseLong(args[i], 16)));
      out.println("\n---- " + (f == null ? "? " + args[i] : f.getName() + " @ " + f.getEntryPoint() + " size=" + f.getBody().getNumAddresses()) + " ----");
      if (f == null) continue; StringBuilder cs = new StringBuilder(); for (Function c : f.getCallingFunctions(monitor)) cs.append(c.getName()).append(' '); out.println("// callers: " + cs);
      DecompileResults r = d.decompileFunction(f, 180, monitor); out.println(r.decompileCompleted() ? r.getDecompiledFunction().getC() : "// FAILED"); out.flush(); }
    d.dispose(); out.close(); println("DumpFuncs wrote " + args[0]); }
}
