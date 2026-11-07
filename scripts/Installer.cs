using System;
using System.IO;
using System.IO.Compression;
using System.Diagnostics;
using System.Reflection;
using System.Windows.Forms;

namespace MirrorSetup {
    static class Program {
        [STAThread]
        static void Main(string[] args) {
            try {
                string localAppData = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
                string installDir = Path.Combine(localAppData, "Mirror");
                string appDir = Path.Combine(installDir, "app");
                string targetExe = Path.Combine(appDir, "mirror_app.exe");

                // Always unpack if target missing or if running setup
                bool needExtract = !File.Exists(targetExe);

                if (needExtract) {
                    if (Directory.Exists(appDir)) {
                        try { Directory.Delete(appDir, true); } catch {}
                    }
                    Directory.CreateDirectory(appDir);

                    using (Stream stream = Assembly.GetExecutingAssembly().GetManifestResourceStream("payload.zip")) {
                        if (stream == null) {
                            MessageBox.Show("Corrupted installer payload.", "Mirror Installer Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
                            return;
                        }
                        using (ZipArchive archive = new ZipArchive(stream)) {
                            archive.ExtractToDirectory(appDir);
                        }
                    }

                    CreateShortcut(
                        Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory), "Mirror.lnk"),
                        targetExe,
                        "Mirror — Android Screen Mirroring & Remote Control by Dev Fahim"
                    );

                    string startMenu = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Programs), "Mirror");
                    if (!Directory.Exists(startMenu)) Directory.CreateDirectory(startMenu);
                    CreateShortcut(
                        Path.Combine(startMenu, "Mirror.lnk"),
                        targetExe,
                        "Mirror — Android Screen Mirroring & Remote Control by Dev Fahim"
                    );
                }

                // If launched with an active installed app, also refresh binaries if needed
                ProcessStartInfo psi = new ProcessStartInfo {
                    FileName = targetExe,
                    Arguments = string.Join(" ", args),
                    WorkingDirectory = appDir,
                    UseShellExecute = false
                };
                Process.Start(psi);

            } catch (Exception ex) {
                MessageBox.Show("Installation / Launch error: " + ex.Message, "Mirror Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
        }

        static void CreateShortcut(string shortcutPath, string targetPath, string description) {
            try {
                Type shellType = Type.GetTypeFromProgID("WScript.Shell");
                if (shellType != null) {
                    dynamic shell = Activator.CreateInstance(shellType);
                    dynamic shortcut = shell.CreateShortcut(shortcutPath);
                    shortcut.TargetPath = targetPath;
                    shortcut.WorkingDirectory = Path.GetDirectoryName(targetPath);
                    shortcut.Description = description;
                    shortcut.Save();
                }
            } catch {}
        }
    }
}

