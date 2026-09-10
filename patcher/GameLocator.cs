using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Text.RegularExpressions;
using Microsoft.Win32;

namespace PAPatcher
{
    /// <summary>Finds Prison Architect64.exe through Steam's registry keys and library folders.</summary>
    public static class GameLocator
    {
        public const string ExeName = "Prison Architect64.exe";
        public const string SteamAppId = "233450";
        const string RelPath = @"steamapps\common\Prison Architect\" + ExeName;

        public static string Find()
        {
            foreach (var lib in SteamLibraries())
            {
                var p = Path.Combine(lib, RelPath);
                if (File.Exists(p)) return p;
            }
            return null;
        }

        public static IEnumerable<string> SteamLibraries()
        {
            var roots = new List<string>();
            foreach (var s in new[] {
                RegRead(@"HKEY_CURRENT_USER\Software\Valve\Steam", "SteamPath"),
                RegRead(@"HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Valve\Steam", "InstallPath"),
                RegRead(@"HKEY_LOCAL_MACHINE\SOFTWARE\Valve\Steam", "InstallPath"),
                @"C:\Program Files (x86)\Steam" })
                if (!string.IsNullOrEmpty(s)) roots.Add(s.Replace('/', '\\'));

            var seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            foreach (var root in roots)
            {
                if (seen.Add(root)) yield return root;
                var vdf = Path.Combine(root, @"steamapps\libraryfolders.vdf");
                if (!File.Exists(vdf)) continue;
                string text; try { text = File.ReadAllText(vdf); } catch { continue; }
                foreach (Match m in Regex.Matches(text, "\"path\"\\s+\"([^\"]+)\""))
                {
                    var lib = m.Groups[1].Value.Replace(@"\\", @"\");
                    if (seen.Add(lib)) yield return lib;
                }
            }
        }

        static string RegRead(string key, string value)
        {
            try { return Registry.GetValue(key, value, null) as string; } catch { return null; }
        }

        public static bool IsGameRunning() =>
            Process.GetProcessesByName("Prison Architect64").Any() || Process.GetProcessesByName("Prison Architect").Any();
    }
}
