// Disassembly (addr, bytes, text) for the patch sites, plus World+0x46c9 users and FUN_1405d6ab0.
import ghidra.app.script.GhidraScript;
import ghidra.app.decompiler.*;
import ghidra.program.model.address.*;
import ghidra.program.model.listing.*;
import ghidra.program.model.scalar.Scalar;
import java.io.*;
import java.util.*;

public class DumpAsm extends GhidraScript {
    PrintWriter out;
    public void run() throws Exception {
        String[] args = getScriptArgs();
        out = new PrintWriter(new FileWriter(args.length > 0 ? args[0] : "D:/projects/prison-architect-handoff-fix/asm.txt"));
        asm(0x1405dd780L, 0x1405ddbA0L, "FUN_1405dd780 guard hand-off routine");
        asm(0x1406aeb00L, 0x1406aecd0L, "FUN_1406ae3c0 tail: state switch + state-10 re-assert");
        asm(0x1404f7600L, 0x1404f76e0L, "FUN_1404f71c0 tail: daily reset / guard pick");
        out.println("\n==== instructions referencing World+0x46c9 ====");
        InstructionIterator it = currentProgram.getListing().getInstructions(true);
        while (it.hasNext()) {
            Instruction ins = it.next();
            for (int i = 0; i < ins.getNumOperands(); i++) for (Object o : ins.getOpObjects(i))
                if (o instanceof Scalar && ((Scalar) o).getUnsignedValue() == 0x46c9L) {
                    Function f = getFunctionContaining(ins.getAddress());
                    out.println("  " + ins.getAddress() + "  " + ins + "   in " + (f == null ? "?" : f.getName()));
                }
        }
        DecompInterface d = new DecompInterface(); d.setOptions(new DecompileOptions()); d.openProgram(currentProgram);
        for (long a : new long[]{0x1405d6ab0L, 0x1405d6870L}) {
            Function f = getFunctionAt(toAddr(a));
            out.println("\n---- " + (f == null ? "?" : f.getName()) + " ----");
            if (f != null) { DecompileResults r = d.decompileFunction(f, 60, monitor); out.println(r.decompileCompleted() ? r.getDecompiledFunction().getC() : "FAILED"); }
        }
        d.dispose(); out.close(); println("DumpAsm done");
    }
    void asm(long lo, long hi, String title) throws Exception {
        out.println("\n==== " + title + " (" + Long.toHexString(lo) + ".." + Long.toHexString(hi) + ") ====");
        Address a = toAddr(lo);
        while (a.getOffset() < hi) {
            Instruction ins = getInstructionAt(a);
            if (ins == null) { ins = getInstructionContaining(a); if (ins == null) { a = a.add(1); continue; } }
            StringBuilder hex = new StringBuilder();
            for (byte b : ins.getBytes()) hex.append(String.format("%02X", b & 0xff));
            out.println(String.format("%s  %-24s %s", ins.getAddress(), hex, ins));
            a = ins.getAddress().add(ins.getLength());
        }
    }
}
