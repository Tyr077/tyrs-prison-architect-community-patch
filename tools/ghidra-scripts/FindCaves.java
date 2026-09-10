// FindCaves.java <out> <minBytes> : list runs of 0x00/0xCC bytes in .text that are outside any function.
import ghidra.app.script.GhidraScript; import ghidra.program.model.address.*; import ghidra.program.model.mem.*; import java.io.*;
public class FindCaves extends GhidraScript {
  public void run() throws Exception {
    String[] a = getScriptArgs(); PrintWriter out = new PrintWriter(new FileWriter(a[0])); int min = Integer.parseInt(a[1]);
    MemoryBlock text = currentProgram.getMemory().getBlock(".text"); Address s = text.getStart(); long end = text.getEnd().getOffset();
    byte[] buf = new byte[(int)(end - s.getOffset() + 1)]; text.getBytes(s, buf);
    int run = 0; long runStart = 0;
    for (int i = 0; i <= buf.length; i++) { boolean pad = i < buf.length && (buf[i] == 0 || buf[i] == (byte)0xCC);
      if (pad) { if (run == 0) runStart = s.getOffset() + i; run++; }
      else { if (run >= min) { Address ra = toAddr(runStart); boolean inFunc = getFunctionContaining(ra) != null || getFunctionContaining(ra.add(run - 1)) != null;
          out.println(String.format("%s  len=%d  %s", ra, run, inFunc ? "INSIDE-FUNCTION" : "free")); } run = 0; } }
    out.close(); println("FindCaves done"); }
}
