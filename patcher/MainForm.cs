using System;
using System.Collections.Generic;
using System.Drawing;
using System.IO;
using System.Linq;
using System.Windows.Forms;

namespace PAPatcher
{
    public class MainForm : Form
    {
        const string GroupFixes = "fixes";
        const string GroupTweaks = "tweaks";

        readonly TextBox txtPath = new TextBox { ReadOnly = true, TabStop = false, Anchor = AnchorStyles.Left | AnchorStyles.Right };
        readonly Button btnBrowse = new Button { Text = "Browse…", AutoSize = true };
        readonly Label lblStatus = new Label { AutoSize = true, Font = new Font(SystemFonts.MessageBoxFont.FontFamily, 11f, FontStyle.Bold) };
        readonly Label lblDetail = new Label { AutoSize = true, MaximumSize = new Size(580, 0) };
        readonly TreeView tree = new TreeView { CheckBoxes = true, Dock = DockStyle.Fill, HideSelection = false, ShowRootLines = true, ShowPlusMinus = true, ItemHeight = 20 };
        readonly Label lblFixInfo = new Label { AutoSize = true, MaximumSize = new Size(580, 0), ForeColor = SystemColors.GrayText };
        readonly Label lblPlan = new Label { AutoSize = true, MaximumSize = new Size(580, 0) };
        readonly Button btnApply = new Button { Text = "Apply selection", AutoSize = true, Padding = new Padding(8, 2, 8, 2) };
        readonly Button btnRevert = new Button { Text = "Revert to original", AutoSize = true, Padding = new Padding(8, 2, 8, 2) };
        readonly Button btnRefresh = new Button { Text = "Re-check", AutoSize = true };
        readonly Button btnCopyHash = new Button { Text = "Copy file hash", AutoSize = true };

        List<PatchDoc> all = new List<PatchDoc>();      // every embedded patch, including hidden bases
        List<PatchDoc> fixes = new List<PatchDoc>();    // what the tree shows
        Settings settings = new Settings();
        readonly Dictionary<string, TreeNode> nodeOf = new Dictionary<string, TreeNode>();
        readonly HashSet<string> chosen = new HashSet<string>();   // patch ids ticked right now
        bool loadingTree;                                          // guards the check-propagation handler
        string exePath;
        byte[] fileBytes;
        string fileHash = "";

        public MainForm()
        {
            Text = "Tyr's Prison Architect Community Patch";
            AutoScaleMode = AutoScaleMode.Dpi;
            ClientSize = new Size(620, 520);
            MinimumSize = new Size(540, 460);
            StartPosition = FormStartPosition.CenterScreen;

            var root = new TableLayoutPanel { Dock = DockStyle.Fill, ColumnCount = 1, Padding = new Padding(12) };
            root.RowStyles.Add(new RowStyle(SizeType.AutoSize));     // path row
            root.RowStyles.Add(new RowStyle(SizeType.AutoSize));     // status
            root.RowStyles.Add(new RowStyle(SizeType.AutoSize));     // detail
            root.RowStyles.Add(new RowStyle(SizeType.AutoSize));     // tree label
            root.RowStyles.Add(new RowStyle(SizeType.Percent, 100)); // tree
            root.RowStyles.Add(new RowStyle(SizeType.AutoSize));     // description of the selected item
            root.RowStyles.Add(new RowStyle(SizeType.AutoSize));     // what Apply will do
            root.RowStyles.Add(new RowStyle(SizeType.AutoSize));     // buttons

            var pathRow = new TableLayoutPanel { Dock = DockStyle.Top, AutoSize = true, ColumnCount = 3 };
            pathRow.ColumnStyles.Add(new ColumnStyle(SizeType.AutoSize));
            pathRow.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
            pathRow.ColumnStyles.Add(new ColumnStyle(SizeType.AutoSize));
            pathRow.Controls.Add(new Label { Text = "Game file:", AutoSize = true, Anchor = AnchorStyles.Left, Margin = new Padding(0, 6, 6, 0) }, 0, 0);
            pathRow.Controls.Add(txtPath, 1, 0);
            pathRow.Controls.Add(btnBrowse, 2, 0);

            var buttons = new FlowLayoutPanel { Dock = DockStyle.Top, AutoSize = true, FlowDirection = FlowDirection.LeftToRight, Margin = new Padding(0, 8, 0, 0) };
            buttons.Controls.AddRange(new Control[] { btnApply, btnRevert, btnRefresh, btnCopyHash });

            root.Controls.Add(pathRow, 0, 0);
            root.Controls.Add(lblStatus, 0, 1);
            root.Controls.Add(lblDetail, 0, 2);
            root.Controls.Add(new Label { Text = "Expand a group to pick individual items, or tick the group for all of it:", AutoSize = true, Margin = new Padding(0, 10, 0, 2) }, 0, 3);
            root.Controls.Add(tree, 0, 4);
            root.Controls.Add(lblFixInfo, 0, 5);
            root.Controls.Add(lblPlan, 0, 6);
            root.Controls.Add(buttons, 0, 7);
            Controls.Add(root);

            btnBrowse.Click += (s, e) => Browse();
            btnRefresh.Click += (s, e) => RefreshState(exePath);
            btnApply.Click += (s, e) => Run(apply: true);
            btnRevert.Click += (s, e) => Run(apply: false);
            btnCopyHash.Click += (s, e) => { if (fileHash != "") { Clipboard.SetText(fileHash); lblDetail.Text = "Hash copied to clipboard."; } };
            tree.AfterSelect += (s, e) => ShowFixInfo();
            tree.AfterCheck += (s, e) => OnChecked(e.Node);
            tree.AfterExpand += (s, e) => RememberExpansion(e.Node);
            tree.AfterCollapse += (s, e) => RememberExpansion(e.Node);
            FormClosing += (s, e) => settings.Save();

            Load += (s, e) =>
            {
                try { all = PatchEngine.LoadEmbedded(); fixes = all.Where(f => !f.hidden).ToList(); }
                catch (Exception ex) { MessageBox.Show(this, "The embedded patch data is corrupt:\n" + ex.Message, Text, MessageBoxButtons.OK, MessageBoxIcon.Error); Close(); return; }
                fixes = fixes.OrderBy(f => f.optional ? 1 : 0).ThenBy(f => f.name, StringComparer.CurrentCultureIgnoreCase).ToList();
                settings = Settings.Load();
                settings.Prune(fixes.Select(f => f.id));
                BuildTree();
                RefreshState(GameLocator.Find());
                tree.Focus();
            };
        }

        // ---- tree ----------------------------------------------------------

        void BuildTree()
        {
            loadingTree = true;
            tree.BeginUpdate();
            tree.Nodes.Clear(); nodeOf.Clear();
            AddGroup(GroupFixes, "Bug fixes", fixes.Where(f => !f.optional).ToList());
            AddGroup(GroupTweaks, "Optional tweaks", fixes.Where(f => f.optional).ToList());
            tree.EndUpdate();
            loadingTree = false;
        }

        void AddGroup(string key, string title, List<PatchDoc> members)
        {
            if (members.Count == 0) return;
            var group = new TreeNode(title) { Tag = key, NodeFont = new Font(tree.Font, FontStyle.Bold) };
            foreach (var f in members)
            {
                var n = new TreeNode(f.DisplayName) { Tag = f };
                nodeOf[f.id] = n;
                group.Nodes.Add(n);
            }
            tree.Nodes.Add(group);
            if (!settings.IsCollapsed(key)) group.Expand();
        }

        void RememberExpansion(TreeNode node)
        {
            var key = node.Tag as string;
            if (loadingTree || key == null) return;
            settings.SetCollapsed(key, !node.IsExpanded);
        }

        /// <summary>Ticking a group ticks everything in it; ticking a member re-derives the group box.</summary>
        void OnChecked(TreeNode node)
        {
            if (loadingTree) return;
            loadingTree = true;
            try
            {
                if (node.Tag is string)
                {
                    foreach (TreeNode child in node.Nodes)
                    {
                        child.Checked = node.Checked;
                        SetChoice((PatchDoc)child.Tag, node.Checked);
                    }
                }
                else
                {
                    SetChoice((PatchDoc)node.Tag, node.Checked);
                    var group = node.Parent;
                    if (group != null) group.Checked = group.Nodes.Cast<TreeNode>().All(c => c.Checked);
                }
            }
            finally { loadingTree = false; }
            UpdateLabels();
            UpdateButtons();
        }

        void SetChoice(PatchDoc f, bool value)
        {
            if (value) chosen.Add(f.id); else chosen.Remove(f.id);
            settings.SetChoice(f.id, value);
        }

        /// <summary>
        /// Fill in the tick boxes: a remembered choice wins, otherwise a fix is on and a tweak is on only
        /// when it is already in the game file, so someone upgrading from an older release keeps what they had.
        /// </summary>
        void ResolveChoices()
        {
            loadingTree = true;
            try
            {
                foreach (var f in fixes)
                {
                    var saved = settings.Choice(f.id);
                    bool value = saved ?? (!f.optional || (fileBytes != null && PatchEngine.GetState(fileBytes, f).IsApplied()));
                    if (value) chosen.Add(f.id); else chosen.Remove(f.id);
                    TreeNode n;
                    if (nodeOf.TryGetValue(f.id, out n)) n.Checked = value;
                }
                foreach (TreeNode group in tree.Nodes)
                    group.Checked = group.Nodes.Count > 0 && group.Nodes.Cast<TreeNode>().All(c => c.Checked);
            }
            finally { loadingTree = false; }
        }

        void UpdateLabels()
        {
            tree.BeginUpdate();
            foreach (TreeNode group in tree.Nodes)
            {
                int applied = 0;
                foreach (TreeNode n in group.Nodes)
                {
                    var f = (PatchDoc)n.Tag;
                    var st = fileBytes == null ? FixState.NotApplicable : PatchEngine.GetState(fileBytes, f);
                    if (fileBytes != null && st.IsApplied()) applied++;
                    n.Text = f.DisplayName + (fileBytes == null ? "" : "  —  " + StateWord(st));
                    n.ForeColor = fileBytes == null ? SystemColors.ControlText : StateColour(st);
                }
                string title = (string)group.Tag == GroupTweaks ? "Optional tweaks" : "Bug fixes";
                int ticked = group.Nodes.Cast<TreeNode>().Count(n => n.Checked);
                group.Text = fileBytes == null
                    ? title + "  (" + group.Nodes.Count + ")"
                    : title + "  —  " + applied + " of " + group.Nodes.Count + " installed, " + ticked + " selected";
            }
            tree.EndUpdate();
        }

        static string StateWord(FixState s)
        {
            switch (s)
            {
                case FixState.Patched: return "installed";
                case FixState.Outdated: return "installed (older version)";
                case FixState.Unpatched: return "not installed";
                default: return "state unknown";
            }
        }

        static Color StateColour(FixState s)
        {
            switch (s)
            {
                case FixState.Patched: return Color.FromArgb(0, 110, 0);
                case FixState.Outdated: return Color.DarkOrange;
                case FixState.Unpatched: return SystemColors.ControlText;
                default: return Color.DarkRed;
            }
        }

        // ---- state ---------------------------------------------------------

        void Browse()
        {
            using (var dlg = new OpenFileDialog { Title = "Locate " + GameLocator.ExeName, Filter = GameLocator.ExeName + "|" + GameLocator.ExeName + "|Executables|*.exe", FileName = GameLocator.ExeName })
            {
                if (!string.IsNullOrEmpty(exePath)) dlg.InitialDirectory = Path.GetDirectoryName(exePath);
                if (dlg.ShowDialog(this) == DialogResult.OK) RefreshState(dlg.FileName);
            }
        }

        void RefreshState(string path)
        {
            exePath = path; fileBytes = null; fileHash = "";
            txtPath.Text = path ?? "";
            if (path == null || !File.Exists(path))
            {
                SetStatus("Game not found", Color.DarkRed, "Could not find " + GameLocator.ExeName + " in your Steam library. Use Browse… to point at it.");
                ResolveChoices(); UpdateLabels(); UpdateButtons(); return;
            }
            try { fileBytes = File.ReadAllBytes(path); }
            catch (Exception ex) { fileBytes = null; SetStatus("Cannot read the game file", Color.DarkRed, ex.Message); ResolveChoices(); UpdateLabels(); UpdateButtons(); return; }
            fileHash = PatchEngine.Sha256(fileBytes);

            if (!PatchEngine.IsSupportedBuild(fileBytes, all))
            {
                fileBytes = null;
                SetStatus("Unsupported game build", Color.DarkRed,
                    "This patcher was made for the Steam Sunset Update build and this file does not match it. " +
                    "Nothing will be changed. If you think it should work, send the file hash (Copy file hash) to the project so the build can be checked.");
                ResolveChoices(); UpdateLabels(); UpdateButtons(); return;
            }

            ResolveChoices();
            var required = fixes.Where(f => !f.optional).ToList();
            int patched = required.Count(f => PatchEngine.GetState(fileBytes, f).IsApplied());
            int tweaks = fixes.Count(f => f.optional && PatchEngine.GetState(fileBytes, f).IsApplied());
            string tweakNote = tweaks == 0 ? "" : " " + tweaks + " optional tweak(s) are on.";
            if (patched == required.Count) SetStatus("Patched", Color.DarkGreen, "All " + required.Count + " fix(es) are installed." + tweakNote + " If Steam ever verifies game files it will undo this; just come back and click Apply again.");
            else if (patched == 0 && tweaks == 0) SetStatus("Not patched", Color.DarkOrange, "Original game file. Tick what you want and click Apply selection. A backup is kept next to the game file.");
            else SetStatus("Partially patched", Color.DarkOrange, patched + " of " + required.Count + " fixes installed." + tweakNote);
            UpdateLabels();
            UpdateButtons();
            ShowFixInfo();
        }

        void SetStatus(string headline, Color color, string detail)
        {
            lblStatus.Text = headline; lblStatus.ForeColor = color; lblDetail.Text = detail;
        }

        void ShowFixInfo()
        {
            var f = tree.SelectedNode == null ? null : tree.SelectedNode.Tag as PatchDoc;
            if (f == null)
            {
                var key = tree.SelectedNode == null ? null : tree.SelectedNode.Tag as string;
                lblFixInfo.Text = key == GroupTweaks
                    ? "Optional tweaks change game balance rather than fixing a bug, so they are off unless you turn them on."
                    : key == GroupFixes ? "Fixes for engine bugs that mods cannot reach. Leave them all on unless you have a reason not to." : "";
                return;
            }
            lblFixInfo.Text = (f.optional ? "Optional tweak, changes game balance: " : "") + f.description;
        }

        // ---- applying ------------------------------------------------------

        IEnumerable<PatchDoc> Selected() => fixes.Where(f => chosen.Contains(f.id));
        List<PatchDoc> ToInstall() => fileBytes == null ? new List<PatchDoc>() : Selected().Where(f => PatchEngine.GetState(fileBytes, f) != FixState.Patched).ToList();
        List<PatchDoc> ToRemove() => fileBytes == null ? new List<PatchDoc>() : fixes.Where(f => !chosen.Contains(f.id) && PatchEngine.GetState(fileBytes, f).IsApplied()).ToList();
        List<PatchDoc> Installed() => fileBytes == null ? new List<PatchDoc>() : fixes.Where(f => PatchEngine.GetState(fileBytes, f).IsApplied()).ToList();

        void UpdateButtons()
        {
            bool ok = fileBytes != null;
            var install = ToInstall(); var remove = ToRemove();
            btnApply.Enabled = ok && (install.Count > 0 || remove.Count > 0);
            btnRevert.Enabled = ok && Installed().Count > 0;
            btnCopyHash.Enabled = fileHash != "";
            btnRefresh.Enabled = exePath != null;

            if (!ok) { lblPlan.Text = ""; return; }
            if (install.Count == 0 && remove.Count == 0) { lblPlan.Text = "The game file already matches your selection."; lblPlan.ForeColor = SystemColors.GrayText; return; }
            var parts = new List<string>();
            if (install.Count > 0) parts.Add("install " + install.Count);
            if (remove.Count > 0) parts.Add("remove " + remove.Count);
            lblPlan.Text = "Apply selection will " + string.Join(" and ", parts) + ".";
            lblPlan.ForeColor = SystemColors.ControlText;
        }

        void Run(bool apply)
        {
            if (fileBytes == null) return;
            if (GameLocator.IsGameRunning())
            {
                MessageBox.Show(this, "Prison Architect is running. Close the game, then try again.", Text, MessageBoxButtons.OK, MessageBoxIcon.Warning);
                return;
            }
            try
            {
                // Re-read right before writing so a Steam update between checks cannot be clobbered.
                var current = File.ReadAllBytes(exePath);
                if (!PatchEngine.IsSupportedBuild(current, all)) throw new InvalidOperationException("The game file changed since it was checked and is no longer a supported build.");

                byte[] result;
                if (apply)
                {
                    // Make the file match the ticked boxes: take out what was unticked, put in what was ticked.
                    var remove = fixes.Where(f => !chosen.Contains(f.id) && PatchEngine.GetState(current, f).IsApplied()).ToList();
                    result = remove.Count > 0 ? PatchEngine.WithEdits(current, remove, apply: false) : current;
                    var install = PatchEngine.ExpandRequires(all, Selected());
                    if (install.Count > 0) result = PatchEngine.WithEdits(result, install, apply: true);
                }
                else
                {
                    // "Revert to original" means the whole file, not just the ticked items.
                    result = PatchEngine.WithEdits(current, fixes.Where(f => PatchEngine.GetState(current, f).IsApplied()).ToList(), apply: false);
                }
                result = PatchEngine.RevertOrphanedBases(result, all);
                if (apply) PatchEngine.EnsureBackup(exePath, current);
                PatchEngine.WriteAtomically(exePath, result);
            }
            catch (UnauthorizedAccessException)
            {
                MessageBox.Show(this, "Windows would not let this program write to the game folder.\n\nRight-click the patcher and choose \"Run as administrator\", then try again.", Text, MessageBoxButtons.OK, MessageBoxIcon.Error);
                return;
            }
            catch (Exception ex)
            {
                MessageBox.Show(this, ex.Message, Text, MessageBoxButtons.OK, MessageBoxIcon.Error);
                return;
            }
            settings.Save();
            RefreshState(exePath);
        }
    }
}
