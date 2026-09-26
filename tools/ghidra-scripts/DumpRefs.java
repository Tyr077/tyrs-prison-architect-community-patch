// DumpRefs.java <out.tsv> : the references DumpAll's index does not have, for matching functions between builds.
//   vt:<Class>[#n]   <slot>   <function entry>     every RTTI-named vtable and the functions in its slots
//   <function entry> ptr      <function entry>     code that takes a function's address without calling it
// No decompiling, so it runs in about a minute.
import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.*;
import ghidra.program.model.listing.*;
import ghidra.program.model.mem.*;
import ghidra.program.model.symbol.*;
import java.io.*;
import java.util.*;

public class DumpRefs extends GhidraScript {
    public void run() throws Exception {
        String[] args = getScriptArgs();
        PrintWriter out = new PrintWriter(new FileWriter(args[0]));
        FunctionManager fm = currentProgram.getFunctionManager();
        Memory mem = currentProgram.getMemory();
        SymbolTable st = currentProgram.getSymbolTable();

        Map<String, Integer> seen = new HashMap<>(); int nvt = 0, nslot = 0, nptr = 0;
        SymbolIterator it = st.getSymbolIterator("vftable", true);
        List<Symbol> vts = new ArrayList<>(); while (it.hasNext()) vts.add(it.next());
        vts.sort(Comparator.comparing(Symbol::getAddress));
        for (Symbol s : vts) {
            String cls = s.getParentNamespace().getName(true);
            int n = seen.merge(cls, 1, Integer::sum);
            String label = "vt:" + cls + (n > 1 ? "#" + n : "");
            Address a = s.getAddress(); nvt++;
            for (int slot = 0; slot < 2000; slot++, a = a.add(8)) {
                if (slot > 0 && st.getPrimarySymbol(a) != null && st.getPrimarySymbol(a).getName().contains("vftable")) break;
                long v; try { v = mem.getLong(a); } catch (MemoryAccessException e) { break; }
                Function f = fm.getFunctionAt(toAddr(v));
                if (f == null) break;
                out.println(label + "\t" + slot + "\t" + f.getEntryPoint()); nslot++;
            }
        }

        for (Function f : fm.getFunctions(true)) {
            if (f.isExternal() || f.isThunk()) continue;
            Set<Address> done = new HashSet<>();
            InstructionIterator ii = currentProgram.getListing().getInstructions(f.getBody(), true);
            while (ii.hasNext()) for (Reference r : ii.next().getReferencesFrom()) {
                if (r.getReferenceType().isCall() || r.getReferenceType().isJump() || !r.getToAddress().isMemoryAddress()) continue;
                Function g = fm.getFunctionAt(r.getToAddress());
                if (g == null || g.equals(f) || !done.add(g.getEntryPoint())) continue;
                out.println(f.getEntryPoint() + "\tptr\t" + g.getEntryPoint()); nptr++;
            }
        }
        out.close();
        println("DumpRefs wrote " + args[0] + ": " + nvt + " vtables, " + nslot + " slots, " + nptr + " function pointer references");
    }
}
