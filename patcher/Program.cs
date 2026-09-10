using System;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices;
using System.Windows.Forms;

namespace PAPatcher
{
    static class Program
    {
        [DllImport("kernel32.dll")] static extern bool AttachConsole(int pid);
        const int ATTACH_PARENT_PROCESS = -1;

        [STAThread]
        static int Main(string[] args)
        {
            if (args.Length > 0 && args[0].StartsWith("--")) return Cli(args);
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            Application.Run(new MainForm());
            return 0;
        }

        // Hidden command-line mode for scripting and testing:
        //   TyrsPAPatch.exe --status [exe]   --apply [exe] [--tweaks]   --revert [exe]
        // --apply installs the bug fixes; add --tweaks to also install the optional balance tweaks. --revert undoes everything.
        static int Cli(string[] args)
        {
            AttachConsole(ATTACH_PARENT_PROCESS);
            var stdout = new StreamWriter(Console.OpenStandardOutput()) { AutoFlush = true };
            try
            {
                var cmd = args[0].ToLowerInvariant();
                var exe = args.Skip(1).FirstOrDefault(a => !a.StartsWith("--")) ?? GameLocator.Find();
                bool withTweaks = args.Any(a => a.Equals("--tweaks", StringComparison.OrdinalIgnoreCase));
                if (exe == null || !File.Exists(exe)) { stdout.WriteLine("Game executable not found. Pass its path as the second argument."); return 2; }
                var fixes = PatchEngine.LoadEmbedded();
                var file = File.ReadAllBytes(exe);
                stdout.WriteLine("Exe:    " + exe);
                stdout.WriteLine("SHA256: " + PatchEngine.Sha256(file));
                stdout.WriteLine("Build:  " + (PatchEngine.IsSupportedBuild(file, fixes) ? "supported" : "UNKNOWN - not the build these patches were made for"));
                foreach (var f in fixes) stdout.WriteLine("  [" + PatchEngine.GetState(file, f) + "] " + (f.hidden ? "(base) " : "") + f.ListLabel);

                if (cmd == "--status") return 0;
                if (cmd != "--apply" && cmd != "--revert") { stdout.WriteLine("Usage: TyrsPAPatch.exe --status|--apply [--tweaks]|--revert [path to Prison Architect64.exe]"); return 1; }
                if (GameLocator.IsGameRunning()) { stdout.WriteLine("Prison Architect is running. Close it first."); return 3; }
                if (!PatchEngine.IsSupportedBuild(file, fixes)) { stdout.WriteLine("Refusing to modify an unsupported build."); return 4; }

                bool apply = cmd == "--apply";
                var set = (apply && !withTweaks) ? fixes.Where(f => !f.optional && !f.hidden).ToList() : fixes.Where(f => !f.hidden).ToList();
                if (apply) set = PatchEngine.ExpandRequires(fixes, set);
                var result = PatchEngine.WithEdits(file, set, apply);
                if (!apply) result = PatchEngine.RevertOrphanedBases(result, fixes);
                if (result.SequenceEqual(file)) { stdout.WriteLine("Nothing to do: already " + (apply ? "patched." : "original.")); return 0; }
                if (apply) PatchEngine.EnsureBackup(exe, file);
                PatchEngine.WriteAtomically(exe, result);
                stdout.WriteLine((apply ? "Applied. " : "Reverted. ") + "New SHA256: " + PatchEngine.Sha256(result));
                return 0;
            }
            catch (Exception ex) { stdout.WriteLine("Error: " + ex.Message); return 5; }
        }
    }
}
