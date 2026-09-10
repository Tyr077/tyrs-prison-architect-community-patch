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
        //   PAPatcher.exe --status [exe]   --apply [exe]   --revert [exe]
        static int Cli(string[] args)
        {
            AttachConsole(ATTACH_PARENT_PROCESS);
            var stdout = new StreamWriter(Console.OpenStandardOutput()) { AutoFlush = true };
            try
            {
                var cmd = args[0].ToLowerInvariant();
                var exe = args.Length > 1 ? args[1] : GameLocator.Find();
                if (exe == null || !File.Exists(exe)) { stdout.WriteLine("Game executable not found. Pass its path as the second argument."); return 2; }
                var fixes = PatchEngine.LoadEmbedded();
                var file = File.ReadAllBytes(exe);
                stdout.WriteLine("Exe:    " + exe);
                stdout.WriteLine("SHA256: " + PatchEngine.Sha256(file));
                stdout.WriteLine("Build:  " + (PatchEngine.IsSupportedBuild(file, fixes) ? "supported" : "UNKNOWN - not the build these patches were made for"));
                foreach (var f in fixes) stdout.WriteLine("  [" + PatchEngine.GetState(file, f) + "] " + f.DisplayName);

                if (cmd == "--status") return 0;
                if (cmd != "--apply" && cmd != "--revert") { stdout.WriteLine("Usage: PAPatcher.exe --status|--apply|--revert [path to Prison Architect64.exe]"); return 1; }
                if (GameLocator.IsGameRunning()) { stdout.WriteLine("Prison Architect is running. Close it first."); return 3; }
                if (!PatchEngine.IsSupportedBuild(file, fixes)) { stdout.WriteLine("Refusing to modify an unsupported build."); return 4; }

                bool apply = cmd == "--apply";
                var result = PatchEngine.WithEdits(file, fixes, apply);
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
