// Disassembles the patched hook sites and code cave of an imported patched exe.
import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.*;
import ghidra.program.model.listing.*;
import java.io.*;

public class VerifyPatch extends GhidraScript {
    PrintWriter out;
    public void run() throws Exception {
        String[] args = getScriptArgs();
        out = new PrintWriter(new FileWriter(args.length > 0 ? args[0] : "D:/projects/prison-architect-handoff-fix/verify.txt"));
        long[][] ranges = {
            {0x1405DD8D4L, 0x1405DD8E5L, 0}, {0x1405DD8F3L, 0x1405DD931L, 0},
            {0x1406AEC10L, 0x1406AEC28L, 0}, {0x1404F7600L, 0x1404F760FL, 0},
            {0x140A44260L, 0x140A44400L, 1}
        };
        for (long[] r : ranges) {
            Address a = toAddr(r[0]);
            out.println("==== " + a + " ====");
            if (r[2] == 1) disassemble(a);
            while (a.getOffset() < r[1]) {
                Instruction ins = getInstructionAt(a);
                if (ins == null) { disassemble(a); ins = getInstructionAt(a); }
                if (ins == null) { out.println(a + "  ?? " + String.format("%02X", getByte(a) & 0xff)); a = a.add(1); continue; }
                StringBuilder hex = new StringBuilder();
                for (byte bb : ins.getBytes()) hex.append(String.format("%02X", bb & 0xff));
                out.println(String.format("%s  %-24s %s", ins.getAddress(), hex, ins));
                a = ins.getAddress().add(ins.getLength());
                if (r[2] == 1 && ins.getMnemonicString().equals("JMP") && a.getOffset() < r[1]) {
                    // keep disassembling past unconditional jumps inside the cave
                    if (getByte(a) == 0 && getByte(a.add(1)) == 0 && getByte(a.add(2)) == 0) { out.println("-- padding --"); a = a.add(8); }
                    disassemble(a);
                }
            }
        }
        out.close(); println("VerifyPatch done");
    }
}
