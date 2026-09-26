using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Runtime.Serialization;
using System.Runtime.Serialization.Json;

namespace PAPatcher
{
    /// <summary>
    /// What the user ticked last time, kept in %AppData%\TyrsPAPatch\settings.json.
    /// Choices are stored per patch id as two lists rather than one map, so a patch the saved file
    /// has never heard of (added by a later release) falls back to its own default instead of
    /// silently arriving switched off.
    /// </summary>
    [DataContract]
    public class Settings
    {
        [DataMember] public List<string> on = new List<string>();
        [DataMember] public List<string> off = new List<string>();
        [DataMember] public List<string> collapsed = new List<string>();

        public static string Path => System.IO.Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "TyrsPAPatch", "settings.json");

        /// <summary>The saved choice for a patch, or null when there is none.</summary>
        public bool? Choice(string id)
        {
            if (on != null && on.Contains(id)) return true;
            if (off != null && off.Contains(id)) return false;
            return null;
        }

        public void SetChoice(string id, bool value)
        {
            if (on == null) on = new List<string>();
            if (off == null) off = new List<string>();
            on.Remove(id); off.Remove(id);
            (value ? on : off).Add(id);
        }

        public bool IsCollapsed(string key) => collapsed != null && collapsed.Contains(key);

        public void SetCollapsed(string key, bool value)
        {
            if (collapsed == null) collapsed = new List<string>();
            collapsed.Remove(key);
            if (value) collapsed.Add(key);
        }

        /// <summary>Never throws: a missing or damaged settings file just means "no preferences yet".</summary>
        public static Settings Load()
        {
            try
            {
                if (!File.Exists(Path)) return new Settings();
                var raw = File.ReadAllBytes(Path);
                // Tolerate a UTF-8 byte-order mark; DataContractJsonSerializer does not. A hand-edited
                // file, or one written by a text editor, may have one.
                int start = (raw.Length >= 3 && raw[0] == 0xEF && raw[1] == 0xBB && raw[2] == 0xBF) ? 3 : 0;
                using (var ms = new MemoryStream(raw, start, raw.Length - start))
                {
                    var s = (Settings)new DataContractJsonSerializer(typeof(Settings)).ReadObject(ms);
                    if (s == null) return new Settings();
                    s.on = s.on ?? new List<string>();
                    s.off = s.off ?? new List<string>();
                    s.collapsed = s.collapsed ?? new List<string>();
                    return s;
                }
            }
            catch { return new Settings(); }
        }

        /// <summary>Never throws: failing to remember choices must not stop anyone patching their game.</summary>
        public void Save()
        {
            try
            {
                Directory.CreateDirectory(System.IO.Path.GetDirectoryName(Path));
                var tmp = Path + ".tmp";
                using (var fs = File.Create(tmp)) new DataContractJsonSerializer(typeof(Settings)).WriteObject(fs, this);
                File.Copy(tmp, Path, true);
                File.Delete(tmp);
            }
            catch { }
        }

        /// <summary>Forget choices for patches that no longer exist, so the file does not grow for ever.</summary>
        public void Prune(IEnumerable<string> knownIds)
        {
            var known = new HashSet<string>(knownIds);
            on = (on ?? new List<string>()).Where(known.Contains).ToList();
            off = (off ?? new List<string>()).Where(known.Contains).ToList();
        }
    }
}
