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
        readonly TextBox txtPath = new TextBox { ReadOnly = true, TabStop = false, Anchor = AnchorStyles.Left | AnchorStyles.Right };
        readonly Button btnBrowse = new Button { Text = "Browse…", AutoSize = true };
        readonly Label lblStatus = new Label { AutoSize = true, Font = new Font(SystemFonts.MessageBoxFont.FontFamily, 11f, FontStyle.Bold) };
        readonly Label lblDetail = new Label { AutoSize = true, MaximumSize = new Size(560, 0) };
        readonly CheckedListBox lstFixes = new CheckedListBox { CheckOnClick = true, IntegralHeight = false, Dock = DockStyle.Fill };
        readonly Label lblFixInfo = new Label { AutoSize = true, MaximumSize = new Size(560, 0), ForeColor = SystemColors.GrayText };
        readonly Button btnApply = new Button { Text = "Apply patch", AutoSize = true, Padding = new Padding(8, 2, 8, 2) };
        readonly Button btnRevert = new Button { Text = "Revert to original", AutoSize = true, Padding = new Padding(8, 2, 8, 2) };
        readonly Button btnRefresh = new Button { Text = "Re-check", AutoSize = true };
        readonly Button btnCopyHash = new Button { Text = "Copy file hash", AutoSize = true };

        List<PatchDoc> fixes = new List<PatchDoc>();
        string exePath;
        byte[] fileBytes;
        string fileHash = "";

        public MainForm()
        {
            Text = "Prison Architect Community Patch";
            AutoScaleMode = AutoScaleMode.Dpi;
            ClientSize = new Size(600, 440);
            MinimumSize = new Size(520, 400);
            StartPosition = FormStartPosition.CenterScreen;

            var root = new TableLayoutPanel { Dock = DockStyle.Fill, ColumnCount = 1, Padding = new Padding(12) };
            root.RowStyles.Add(new RowStyle(SizeType.AutoSize));   // path row
            root.RowStyles.Add(new RowStyle(SizeType.AutoSize));   // status
            root.RowStyles.Add(new RowStyle(SizeType.AutoSize));   // detail
            root.RowStyles.Add(new RowStyle(SizeType.AutoSize));   // "Fixes" label
            root.RowStyles.Add(new RowStyle(SizeType.Percent, 100)); // list
            root.RowStyles.Add(new RowStyle(SizeType.AutoSize));   // fix info
            root.RowStyles.Add(new RowStyle(SizeType.AutoSize));   // buttons

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
            root.Controls.Add(new Label { Text = "Fixes included in this patcher:", AutoSize = true, Margin = new Padding(0, 10, 0, 2) }, 0, 3);
            root.Controls.Add(lstFixes, 0, 4);
            root.Controls.Add(lblFixInfo, 0, 5);
            root.Controls.Add(buttons, 0, 6);
            Controls.Add(root);

            btnBrowse.Click += (s, e) => Browse();
            btnRefresh.Click += (s, e) => RefreshState(exePath);
            btnApply.Click += (s, e) => Run(apply: true);
            btnRevert.Click += (s, e) => Run(apply: false);
            btnCopyHash.Click += (s, e) => { if (fileHash != "") { Clipboard.SetText(fileHash); lblDetail.Text = "Hash copied to clipboard."; } };
            lstFixes.SelectedIndexChanged += (s, e) => ShowFixInfo();
            lstFixes.ItemCheck += (s, e) => BeginInvoke(new Action(UpdateButtons));

            Load += (s, e) =>
            {
                try { fixes = PatchEngine.LoadEmbedded(); }
                catch (Exception ex) { MessageBox.Show(this, "The embedded patch data is corrupt:\n" + ex.Message, Text, MessageBoxButtons.OK, MessageBoxIcon.Error); Close(); return; }
                foreach (var f in fixes) lstFixes.Items.Add(f.DisplayName, true);
                if (lstFixes.Items.Count > 0) lstFixes.SelectedIndex = 0;
                RefreshState(GameLocator.Find());
                lstFixes.Focus();
            };
        }

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
                UpdateButtons(); return;
            }
            try { fileBytes = File.ReadAllBytes(path); }
            catch (Exception ex) { SetStatus("Cannot read the game file", Color.DarkRed, ex.Message); UpdateButtons(); return; }
            fileHash = PatchEngine.Sha256(fileBytes);

            if (!PatchEngine.IsSupportedBuild(fileBytes, fixes))
            {
                SetStatus("Unsupported game build", Color.DarkRed,
                    "This patcher was made for the Steam Sunset Update build and this file does not match it. " +
                    "Nothing will be changed. If you think it should work, send the file hash (Copy file hash) to the project so the build can be checked.");
                UpdateButtons(); return;
            }

            int patched = fixes.Count(f => PatchEngine.GetState(fileBytes, f) == FixState.Patched);
            if (patched == fixes.Count) SetStatus("Patched", Color.DarkGreen, "All " + fixes.Count + " fix(es) are applied. If Steam ever verifies game files it will undo this; just come back and click Apply again.");
            else if (patched == 0) SetStatus("Not patched", Color.DarkOrange, "Original game file. Click Apply patch to install the selected fixes. A backup is kept next to the game file.");
            else SetStatus("Partially patched", Color.DarkOrange, patched + " of " + fixes.Count + " fixes applied.");
            UpdateButtons();
            ShowFixInfo();
        }

        void SetStatus(string headline, Color color, string detail)
        {
            lblStatus.Text = headline; lblStatus.ForeColor = color; lblDetail.Text = detail;
        }

        void ShowFixInfo()
        {
            var i = lstFixes.SelectedIndex;
            if (i < 0 || i >= fixes.Count) { lblFixInfo.Text = ""; return; }
            var f = fixes[i];
            var st = fileBytes == null ? "" : "  [" + PatchEngine.GetState(fileBytes, f) + "]";
            lblFixInfo.Text = f.description + st;
        }

        IEnumerable<PatchDoc> SelectedFixes() => fixes.Where((f, i) => lstFixes.GetItemChecked(i));

        void UpdateButtons()
        {
            bool ok = fileBytes != null && PatchEngine.IsSupportedBuild(fileBytes, fixes);
            var sel = ok ? SelectedFixes().ToList() : new List<PatchDoc>();
            btnApply.Enabled = ok && sel.Any(f => PatchEngine.GetState(fileBytes, f) == FixState.Unpatched);
            btnRevert.Enabled = ok && sel.Any(f => PatchEngine.GetState(fileBytes, f) == FixState.Patched);
            btnCopyHash.Enabled = fileHash != "";
            btnRefresh.Enabled = exePath != null;
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
                if (!PatchEngine.IsSupportedBuild(current, fixes)) throw new InvalidOperationException("The game file changed since it was checked and is no longer a supported build.");
                var result = PatchEngine.WithEdits(current, SelectedFixes(), apply);
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
            RefreshState(exePath);
        }
    }
}
