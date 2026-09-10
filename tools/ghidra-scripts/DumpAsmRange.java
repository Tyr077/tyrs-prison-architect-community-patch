// DumpAsmRange.java <out> <lo> <hi> [<lo> <hi> ...] : disassembly listing with bytes for address ranges.
import ghidra.app.script.GhidraScript; import ghidra.program.model.address.*; import ghidra.program.model.listing.*; import java.io.*;
public class DumpAsmRange extends GhidraScript {
  public void run() throws Exception {
    String[] a = getScriptArgs(); PrintWriter out = new PrintWriter(new FileWriter(a[0]));
    for (int i = 1; i + 1 < a.length; i += 2) { long lo = Long.parseLong(a[i].replace("0x",""), 16), hi = Long.parseLong(a[i+1].replace("0x",""), 16);
      out.println("==== " + a[i] + ".." + a[i+1] + " ===="); Address p = toAddr(lo); disassemble(p);
      while (p.getOffset() < hi) { Instruction ins = getInstructionAt(p); if (ins == null) { ins = getInstructionContaining(p); if (ins == null) { out.println(p + "  ??"); p = p.add(1); continue; } }
        StringBuilder hex = new StringBuilder(); for (byte b : ins.getBytes()) hex.append(String.format("%02X", b & 0xff));
        out.println(String.format("%s  %-26s %s", ins.getAddress(), hex, ins)); p = ins.getAddress().add(ins.getLength()); } }
    out.close(); println("DumpAsmRange done"); }
}
