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
        // Replacement bytes written by earlier versions of this patch, newest first. Lets the patcher
        // recognise a file left by an older release and rewrite or revert it cleanly.
        [DataMember] public List<string> superseded;

        public byte[] ExpectBytes => Hex.Parse(expect);
        public byte[] ReplaceBytes => Hex.Parse(replace);
        public int SupersededCount => superseded == null ? 0 : superseded.Count;
        /// <summary>The bytes version <paramref name="k"/> of this patch wrote at this site: its own if this edit changed, else the current ones.</summary>
        public byte[] SupersededBytes(int k) =>
            (superseded != null && k < superseded.Count && !string.IsNullOrEmpty(superseded[k])) ? Hex.Parse(superseded[k]) : ReplaceBytes;
        // An edit with no expected bytes appends its replacement at end of file (offset == original length).
        public bool IsAppend => string.IsNullOrEmpty(expect);
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
        // Optional tweak: changes game balance rather than fixing a bug. Off by default in the UI and in --apply.
        [DataMember] public bool optional;
        // Hidden base patch (e.g. the appended code section): never listed, applied when a patch requires it.
        [DataMember] public bool hidden;
        // Ids of patches that must be applied first (their edits may live inside a base patch's section).
        [DataMember] public List<string> requires;
        public bool HasRequires => requires != null && requires.Count > 0;

        public string DisplayName => string.IsNullOrEmpty(version) ? name : name + " v" + version;
        public string ListLabel => (optional ? "[Optional] " : "") + DisplayName;
    }

    public enum FixState { Unpatched, Patched, Outdated, Mixed, NotApplicable }

    public static class FixStateExt
    {
        /// <summary>Present in the file, whether written by this release or an older one.</summary>
        public static bool IsApplied(this FixState s) => s == FixState.Patched || s == FixState.Outdated;
    }

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
                if (!e.IsAppend && e.ExpectBytes.Length != e.ReplaceBytes.Length) throw new InvalidDataException("edit at " + e.va + ": expect/replace length mismatch");
            return doc;
        }

        public static string Sha256(byte[] data)
        {
            using (var sha = SHA256.Create()) return Hex.Format(sha.ComputeHash(data));
        }

        public static FixState GetState(byte[] file, PatchDoc p)
        {
            // One flag per layout this patch has ever written: the current one, the original bytes,
            // and one for each superseded version, so a file left by an older release is still recognised.
            int versions = p.edits.Count == 0 ? 0 : p.edits.Max(e => e.SupersededCount);
            bool allOrig = true, allNew = true;
            var allOld = new bool[versions];
            for (int k = 0; k < versions; k++) allOld[k] = true;
            foreach (var e in p.edits)
            {
                var exp = e.ExpectBytes; var rep = e.ReplaceBytes;
                if (e.IsAppend)
                {
                    // Presence only: other patches write into the appended region, so its content is not compared.
                    if (file.Length == e.offset) { allNew = false; for (int k = 0; k < versions; k++) allOld[k] = false; continue; }
                    if (file.Length >= e.offset + rep.Length) { allOrig = false; continue; }
                    return FixState.NotApplicable;
                }
                // Edits inside a required base patch's section are out of range until that base is applied.
                // They count as still holding their original bytes, so a patch that gained the requirement in a
                // later version is still recognised as Outdated from its other edits.
                if (e.offset < 0 || e.offset + exp.Length > file.Length)
                {
                    if (!p.HasRequires) return FixState.NotApplicable;
                    allNew = false;
                    for (int k = 0; k < versions; k++)
                        if (allOld[k] && !e.SupersededBytes(k).SequenceEqual(exp)) allOld[k] = false;
                    continue;
                }
                for (int k = 0; k < versions; k++)
                {
                    if (!allOld[k]) continue;
                    var oldBytes = e.SupersededBytes(k);
                    if (oldBytes.Length != exp.Length) { allOld[k] = false; continue; }
                    for (int i = 0; i < exp.Length && allOld[k]; i++) if (file[e.offset + i] != oldBytes[i]) allOld[k] = false;
                }
                for (int i = 0; i < exp.Length; i++)
                {
                    byte cur = file[e.offset + i];
                    if (cur != exp[i]) allOrig = false;
                    if (cur != rep[i]) allNew = false;
                }
            }
            if (allNew) return FixState.Patched;
            if (allOrig) return FixState.Unpatched;
            for (int k = 0; k < versions; k++) if (allOld[k]) return FixState.Outdated;
            return FixState.Mixed;
        }

        /// <summary>
        /// True if this file is the build the patches were made for, in any patched/unpatched combination.
        /// Every fix must be cleanly patched (by this or an older release) or unpatched, and reverting the patched ones must give back
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
            // Bases (no requirements) go first when applying; dependents go first when reverting.
            var ordered = apply ? fixes.OrderBy(p => p.HasRequires ? 1 : 0).ToList() : fixes.OrderBy(p => p.HasRequires ? 0 : 1).ToList();
            foreach (var p in ordered)
            {
                var st = GetState(outb, p);
                if (apply && st == FixState.Patched) continue;
                if (!apply && st == FixState.Unpatched) continue;
                if (st == FixState.Mixed || st == FixState.NotApplicable)
                    throw new InvalidOperationException("'" + p.name + "': bytes match neither the original nor the patched layout. Refusing to touch this file.");
                foreach (var e in p.edits)
                {
                    if (e.IsAppend)
                    {
                        var rep = e.ReplaceBytes;
                        if (apply && outb.Length == e.offset) { var n = new byte[outb.Length + rep.Length]; Array.Copy(outb, n, outb.Length); Array.Copy(rep, 0, n, outb.Length, rep.Length); outb = n; }
                        else if (!apply && outb.Length >= e.offset + rep.Length) { var n = new byte[e.offset]; Array.Copy(outb, n, n.Length); outb = n; }
                        continue;
                    }
                    var src = apply ? e.ReplaceBytes : e.ExpectBytes;
                    // Reverting an older layout that had nothing in the base patch's section, with the section absent.
                    if (!apply && e.offset + src.Length > outb.Length) continue;
                    Array.Copy(src, 0, outb, e.offset, src.Length);
                }
            }
            return outb;
        }

        /// <summary>The selection plus every patch it requires, transitively.</summary>
        public static List<PatchDoc> ExpandRequires(IList<PatchDoc> all, IEnumerable<PatchDoc> selected)
        {
            var result = new List<PatchDoc>(); var queue = new Queue<PatchDoc>(selected);
            while (queue.Count > 0)
            {
                var p = queue.Dequeue();
                if (result.Contains(p)) continue;
                if (p.HasRequires)
                    foreach (var id in p.requires)
                    {
                        var dep = all.FirstOrDefault(d => d.id == id);
                        if (dep == null) throw new InvalidOperationException("'" + p.name + "' requires missing patch '" + id + "'.");
                        queue.Enqueue(dep);
                    }
                result.Add(p);
            }
            return result;
        }

        /// <summary>Revert hidden base patches that no applied patch requires any more.</summary>
        public static byte[] RevertOrphanedBases(byte[] file, IList<PatchDoc> all)
        {
            var outb = file; bool changed = true;
            while (changed)
            {
                changed = false;
                foreach (var b in all.Where(d => d.hidden))
                {
                    if (!GetState(outb, b).IsApplied()) continue;
                    bool needed = all.Any(d => d != b && d.HasRequires && d.requires.Contains(b.id) && GetState(outb, d).IsApplied());
                    if (!needed) { outb = WithEdits(outb, new[] { b }, apply: false); changed = true; }
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
