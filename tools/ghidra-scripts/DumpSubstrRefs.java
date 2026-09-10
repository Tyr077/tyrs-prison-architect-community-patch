// DumpSubstrRefs.java <out> <substr>... : find every null-terminated string in .rdata/.data that CONTAINS a
// substring, print the full string, its address and referencing functions, and decompile the referencers
// (each function once, size-capped). Useful when the literal has format specifiers or trailing spaces.
import ghidra.app.script.GhidraScript; import ghidra.app.decompiler.*; import ghidra.program.model.address.*;
import ghidra.program.model.listing.*; import ghidra.program.model.mem.*; import ghidra.program.model.symbol.*; import java.io.*; import java.util.*;
public class DumpSubstrRefs extends GhidraScript {
  public void run() throws Exception {
    String[] args = getScriptArgs(); PrintWriter out = new PrintWriter(new FileWriter(args[0]));
    DecompInterface d = new DecompInterface(); d.setOptions(new DecompileOptions()); d.openProgram(currentProgram);
    Memory mem = currentProgram.getMemory(); ReferenceManager rm = currentProgram.getReferenceManager(); Set<Long> done = new HashSet<>();
    for (int ai = 1; ai < args.length; ai++) {
      byte[] pat = args[ai].getBytes("US-ASCII"); out.println("\n==== substring \"" + args[ai] + "\" ====");
      for (MemoryBlock blk : mem.getBlocks()) { if (!blk.getName().equals(".rdata") && !blk.getName().equals(".data")) continue;
        Address a = blk.getStart();
        while (a != null && a.compareTo(blk.getEnd()) < 0) {
          Address hit = mem.findBytes(a, pat, null, true, monitor); if (hit == null || hit.compareTo(blk.getEnd()) > 0) break;
          Address s = hit; while (s.getOffset() > blk.getStart().getOffset() && mem.getByte(s.subtract(1)) != 0) s = s.subtract(1);
          Address e = hit; while (e.compareTo(blk.getEnd()) < 0 && mem.getByte(e) != 0) e = e.add(1);
          byte[] sb = new byte[(int)(e.getOffset() - s.getOffset())]; mem.getBytes(s, sb);
          String str = new String(sb, "ISO-8859-1").replace("\n", "\n").replace("\r", "\r");
          if (sb.length <= 200) { List<String> refs = new ArrayList<>();
            for (Reference r : rm.getReferencesTo(s)) { Function f = getFunctionContaining(r.getFromAddress()); refs.add((f == null ? "?" : f.getName()) + "@" + r.getFromAddress()); }
            out.println("string @ " + s + " \"" + str + "\"  refs: " + refs);
            for (Reference r : rm.getReferencesTo(s)) { Function f = getFunctionContaining(r.getFromAddress()); if (f == null || done.contains(f.getEntryPoint().getOffset())) continue; done.add(f.getEntryPoint().getOffset());
              if (f.getBody().getNumAddresses() > 30000) { out.println("---- " + f.getName() + " too big ----"); continue; }
              out.println("\n---- " + f.getName() + " @ " + f.getEntryPoint() + " size=" + f.getBody().getNumAddresses() + " ----");
              DecompileResults res = d.decompileFunction(f, 180, monitor); out.println(res.decompileCompleted() ? res.getDecompiledFunction().getC() : "// FAILED"); out.flush(); } }
          a = e.add(1);
        } }
    }
    d.dispose(); out.close(); println("DumpSubstrRefs wrote " + args[0]); }
}
