// DumpDispSites.java <out> <ctx> <hexDisp>... : every instruction using a displacement, with <ctx> instructions of context before and after (works for functions too big to decompile).
import ghidra.app.script.GhidraScript; import ghidra.program.model.listing.*; import ghidra.program.model.scalar.Scalar; import java.io.*; import java.util.*;
public class DumpDispSites extends GhidraScript {
  public void run() throws Exception {
    String[] args = getScriptArgs(); PrintWriter out = new PrintWriter(new FileWriter(args[0]));
    int ctx = Integer.parseInt(args[1]);
    List<Long> want = new ArrayList<>(); for (int i = 2; i < args.length; i++) want.add(Long.decode(args[i]));
    Listing l = currentProgram.getListing();
    InstructionIterator it = l.getInstructions(true);
    while (it.hasNext()) { Instruction ins = it.next(); boolean hit = false;
      for (int i = 0; i < ins.getNumOperands() && !hit; i++) for (Object o : ins.getOpObjects(i)) if (o instanceof Scalar && want.contains(((Scalar) o).getUnsignedValue())) { hit = true; break; }
      if (!hit) continue;
      Function f = getFunctionContaining(ins.getAddress());
      out.println("\n== " + ins.getAddress() + " in " + (f == null ? "?" : f.getName() + " @ " + f.getEntryPoint()) + " : " + ins);
      Instruction p = ins; List<String> before = new ArrayList<>();
      for (int i = 0; i < ctx && p != null; i++) { p = p.getPrevious(); if (p != null) before.add(0, "   " + p.getAddress() + "  " + p); }
      for (String s : before) out.println(s);
      out.println(" > " + ins.getAddress() + "  " + ins);
      Instruction n = ins;
      for (int i = 0; i < ctx && n != null; i++) { n = n.getNext(); if (n != null) out.println("   " + n.getAddress() + "  " + n); }
    }
    out.close(); println("DumpDispSites wrote " + args[0]); }
}
