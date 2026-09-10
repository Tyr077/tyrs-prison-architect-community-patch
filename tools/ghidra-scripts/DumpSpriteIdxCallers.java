// DumpSpriteIdxCallers.java <out> <fnHex> <disp> : find call sites of fn where EDX was loaded from [reg+disp]
// within the 6 preceding instructions, and decompile the containing functions.
import ghidra.app.script.GhidraScript; import ghidra.app.decompiler.*; import ghidra.program.model.address.*; import ghidra.program.model.listing.*; import ghidra.program.model.symbol.*; import ghidra.program.model.scalar.Scalar; import java.io.*; import java.util.*;
public class DumpSpriteIdxCallers extends GhidraScript {
  public void run() throws Exception {
    String[] a = getScriptArgs(); PrintWriter out = new PrintWriter(new FileWriter(a[0])); Address fn = toAddr(Long.parseLong(a[1], 16)); long disp = Long.decode(a[2]);
    Map<Function, List<String>> hits = new LinkedHashMap<>();
    for (Reference r : getReferencesTo(fn)) { if (!r.getReferenceType().isCall()) continue;
      Instruction ins = getInstructionAt(r.getFromAddress()); if (ins == null) continue; Instruction p = ins; boolean found = false; String where = "";
      for (int k = 0; k < 6 && p != null; k++) { p = p.getPrevious(); if (p == null) break; String s = p.toString();
        if (s.startsWith("MOV EDX") || s.startsWith("MOVSXD RDX") || s.startsWith("MOV RDX")) { for (int i = 0; i < p.getNumOperands(); i++) for (Object o : p.getOpObjects(i)) if (o instanceof Scalar && ((Scalar) o).getUnsignedValue() == disp) { found = true; where = p.getAddress() + ": " + s; } if (found) break; if (s.startsWith("MOV EDX") || s.startsWith("MOV RDX")) break; } }
      if (found) { Function f = getFunctionContaining(ins.getAddress()); if (f != null) hits.computeIfAbsent(f, x -> new ArrayList<>()).add(ins.getAddress() + " (" + where + ")"); } }
    out.println("==== call sites of " + fn + " with EDX from [reg+0x" + Long.toHexString(disp) + "] ===="); for (Map.Entry<Function, List<String>> e : hits.entrySet()) { out.println(e.getKey().getName() + " @ " + e.getKey().getEntryPoint() + " size=" + e.getKey().getBody().getNumAddresses()); for (String s : e.getValue()) out.println("    " + s); }
    DecompInterface d = new DecompInterface(); d.setOptions(new DecompileOptions()); d.openProgram(currentProgram);
    for (Function f : hits.keySet()) { out.println("\n---- " + f.getName() + " @ " + f.getEntryPoint() + " size=" + f.getBody().getNumAddresses() + " ----"); StringBuilder cs = new StringBuilder(); for (Function c : f.getCallingFunctions(monitor)) cs.append(c.getName()).append(' '); out.println("// callers: " + cs);
      if (f.getBody().getNumAddresses() > 20000) { out.println("// skipped: too big"); continue; } DecompileResults r = d.decompileFunction(f, 180, monitor); out.println(r.decompileCompleted() ? r.getDecompiledFunction().getC() : "// FAILED"); out.flush(); }
    d.dispose(); out.close(); println("DumpSpriteIdxCallers done"); }
}
