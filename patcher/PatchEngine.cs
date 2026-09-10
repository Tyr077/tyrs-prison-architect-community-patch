using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Runtime.Serialization;
using System.Runtime.Serialization.Json;
using System.Security.Cryptography;

namespace PAPatcher
{
    [DataContract]
    public class PatchEdit
    {
        [DataMember] public string va;
        [DataMember] public long offset;
        [DataMember] public string expect;
        [DataMember] public string replace;
        [DataMember] public string note;

        public byte[] ExpectBytes => Hex.Parse(expect);
        public byte[] ReplaceBytes => Hex.Parse(replace);
    }

    [DataContract]
    public class PatchDoc
    {
        [DataMember] public string id;
        [DataMember] public string name;
        [DataMember] public string version;
        [DataMember] public string description;
        [DataMember] public string game_build;
        [DataMember] public string sha256_original;
        [DataMember] public string sha256_patched;
        [DataMember] public List<PatchEdit> edits;

        public string DisplayName => string.IsNullOrEmpty(version) ? name : name + " v" + version;
    }

    public enum FixState { Unpatched, Patched, Mixed, NotApplicable }

    public static class Hex
    {
        public static byte[] Parse(string h)
        {
            if (h == null) return new byte[0];
            var s = h.Replace(" ", "");
            var b = new byte[s.Length / 2];
            for (int i = 0; i < b.Length; i++) b[i] = Convert.ToByte(s.Substring(i * 2, 2), 16);
            return b;
        }
        public static string Format(byte[] b) => BitConverter.ToString(b).Replace("-", "").ToLowerInvariant();
    }

    /// <summary>Pure byte-level patch logic. No UI, no game lookup.</summary>
    public static class PatchEngine
    {
        public const string BackupSuffix = ".orig";

        public static List<PatchDoc> LoadEmbedded()
        {
            var asm = typeof(PatchEngine).Assembly;
            var docs = new List<PatchDoc>();
            foreach (var res in asm.GetManifestResourceNames().Where(n => n.EndsWith(".patch.json", StringComparison.OrdinalIgnoreCase)).OrderBy(n => n))
                using (var s = asm.GetManifestResourceStream(res))
                    docs.Add(Parse(s));
            return docs;
        }

        public static PatchDoc Parse(Stream s)
        {
            // Tolerate a UTF-8 byte-order mark; DataContractJsonSerializer does not.
            byte[] raw;
            using (var ms = new MemoryStream()) { s.CopyTo(ms); raw = ms.ToArray(); }
            int start = (raw.Length >= 3 && raw[0] == 0xEF && raw[1] == 0xBB && raw[2] == 0xBF) ? 3 : 0;
            var ser = new DataContractJsonSerializer(typeof(PatchDoc));
            PatchDoc doc;
            using (var ms = new MemoryStream(raw, start, raw.Length - start)) doc = (PatchDoc)ser.ReadObject(ms);
            if (doc.edits == null || doc.edits.Count == 0) throw new InvalidDataException("patch has no edits");
            foreach (var e in doc.edits)
                if (e.ExpectBytes.Length != e.ReplaceBytes.Length) throw new InvalidDataException("edit at " + e.va + ": expect/replace length mismatch");
            return doc;
        }

        public static string Sha256(byte[] data)
        {
            using (var sha = SHA256.Create()) return Hex.Format(sha.ComputeHash(data));
        }

        public static FixState GetState(byte[] file, PatchDoc p)
        {
            bool allOrig = true, allNew = true;
            foreach (var e in p.edits)
            {
                var exp = e.ExpectBytes; var rep = e.ReplaceBytes;
                if (e.offset < 0 || e.offset + exp.Length > file.Length) return FixState.NotApplicable;
                for (int i = 0; i < exp.Length; i++)
                {
                    byte cur = file[e.offset + i];
                    if (cur != exp[i]) allOrig = false;
                    if (cur != rep[i]) allNew = false;
                }
            }
            if (allNew) return FixState.Patched;
            if (allOrig) return FixState.Unpatched;
            return FixState.Mixed;
        }

        /// <summary>
        /// True if this file is the build the patches were made for, in any patched/unpatched combination.
        /// Every fix must be cleanly patched or unpatched, and reverting the patched ones must give back
        /// a file whose whole-file hash is the known original. A different build that merely matches at
        /// the hook sites is rejected.
        /// </summary>
        public static bool IsSupportedBuild(byte[] file, IList<PatchDoc> fixes)
        {
            if (fixes.Count == 0) return false;
            foreach (var f in fixes)
            {
                var st = GetState(file, f);
                if (st == FixState.Mixed || st == FixState.NotApplicable) return false;
            }
            var normalized = WithEdits(file, fixes, apply: false);
            var hash = Sha256(normalized);
            return fixes.Any(f => string.Equals(hash, f.sha256_original, StringComparison.OrdinalIgnoreCase));
        }

        public static byte[] WithEdits(byte[] file, IEnumerable<PatchDoc> fixes, bool apply)
        {
            var outb = (byte[])file.Clone();
            foreach (var p in fixes)
            {
                var st = GetState(outb, p);
                if (apply && st == FixState.Patched) continue;
                if (!apply && st == FixState.Unpatched) continue;
                if (st == FixState.Mixed || st == FixState.NotApplicable)
                    throw new InvalidOperationException("'" + p.name + "': bytes match neither the original nor the patched layout. Refusing to touch this file.");
                foreach (var e in p.edits)
                {
                    var src = apply ? e.ReplaceBytes : e.ExpectBytes;
                    Array.Copy(src, 0, outb, e.offset, src.Length);
                }
            }
            return outb;
        }

        public static void WriteAtomically(string path, byte[] data)
        {
            var tmp = path + ".tmp";
            File.WriteAllBytes(tmp, data);
            File.Copy(tmp, path, true);
            File.Delete(tmp);
        }

        public static void EnsureBackup(string path, byte[] originalBytes)
        {
            var bak = path + BackupSuffix;
            if (!File.Exists(bak)) File.WriteAllBytes(bak, originalBytes);
        }
    }
}
