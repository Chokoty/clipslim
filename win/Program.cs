using System.Collections.Specialized;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
using SixLabors.ImageSharp.Formats.Webp;
using SixLabors.ImageSharp.Processing;
using Img = SixLabors.ImageSharp.Image;

namespace ClipSlim;

static class Native
{
    public const int WmClipboardUpdate = 0x031D;
    public const int AttachParentProcess = -1;

    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool AddClipboardFormatListener(IntPtr hwnd);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool RemoveClipboardFormatListener(IntPtr hwnd);

    [DllImport("kernel32.dll")]
    public static extern bool AttachConsole(int pid);

    [DllImport("kernel32.dll")]
    public static extern IntPtr GetConsoleWindow();

    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

    public const int SwHide = 0;
}

static class Convert
{
    public const int Quality = 82;
    public const int MaxEdge = 2560;
    public const int KeepTemps = 12;

    public static string CacheDir()
    {
        var dir = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "clipslim");
        Directory.CreateDirectory(dir);
        return dir;
    }

    public static string Bytes(long n)
    {
        if (n < 1024) return $"{n} B";
        if (n < 1024 * 1024) return $"{n / 1024.0:0.0} KB";
        return $"{n / (1024.0 * 1024.0):0.00} MB";
    }

    public static bool IsOurs(string path)
    {
        var full = Path.GetFullPath(path);
        var cache = Path.GetFullPath(CacheDir());
        return full.StartsWith(cache + Path.DirectorySeparatorChar, StringComparison.OrdinalIgnoreCase)
            && Path.GetExtension(full).Equals(".webp", StringComparison.OrdinalIgnoreCase);
    }

    public static byte[] Encode(byte[] input)
    {
        using var image = Img.Load(input);
        return EncodeLoaded(image);
    }

    public static byte[] EncodeFile(string path)
    {
        using var image = Img.Load(path);
        return EncodeLoaded(image);
    }

    static byte[] EncodeLoaded(Img image)
    {
        var w = image.Width;
        var h = image.Height;
        var edge = Math.Max(w, h);
        if (edge > MaxEdge)
        {
            var scale = MaxEdge / (double)edge;
            w = Math.Max(1, (int)Math.Round(w * scale));
            h = Math.Max(1, (int)Math.Round(h * scale));
            image.Mutate(ctx => ctx.Resize(w, h));
        }
        using var ms = new MemoryStream();
        image.Save(ms, new WebpEncoder
        {
            Quality = Quality,
            FileFormat = WebpFileFormatType.Lossy,
        });
        return ms.ToArray();
    }

    public static string WriteTemp(byte[] data)
    {
        var stamp = DateTime.Now.ToString("yyyy-MM-ddTHH-mm-ss");
        var path = Path.Combine(CacheDir(), $"slim-{stamp}.webp");
        File.WriteAllBytes(path, data);
        Prune();
        return path;
    }

    static void Prune()
    {
        var files = Directory.GetFiles(CacheDir(), "slim-*.webp")
            .Select(p => new FileInfo(p))
            .OrderByDescending(f => f.LastWriteTimeUtc)
            .Skip(KeepTemps);
        foreach (var f in files)
        {
            try { f.Delete(); } catch { }
        }
    }

    public static int Cli(string input, string output)
    {
        try
        {
            var data = EncodeFile(input);
            Directory.CreateDirectory(Path.GetDirectoryName(Path.GetFullPath(output)) ?? ".");
            File.WriteAllBytes(output, data);
            var orig = new FileInfo(input).Length;
            Console.WriteLine($"{Bytes(orig)} → {Bytes(data.Length)} WebP");
            return 0;
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine(ex.Message);
            return 1;
        }
    }
}

sealed class App : Form
{
    readonly NotifyIcon tray;
    readonly ContextMenuStrip menu;
    readonly ToolStripMenuItem toggle;
    readonly ToolStripMenuItem notifyToggle;
    readonly ToolStripMenuItem sourceItem;
    readonly ToolStripMenuItem status;
    readonly ToolStripMenuItem save;
    string lastStatus = "복사하면 WebP로 바꿉니다";
    string? lastFile;
    bool converting;
    bool on;
    bool notify;

    public App()
    {
        ShowInTaskbar = false;
        FormBorderStyle = FormBorderStyle.FixedToolWindow;
        Opacity = 0;
        Width = 0;
        Height = 0;
        Text = "clipslim";

        on = LoadOn();
        notify = LoadNotify();
        menu = new ContextMenuStrip();
        toggle = new ToolStripMenuItem("변환", null, (_, _) => Toggle())
        {
            Checked = on,
            CheckOnClick = false,
        };
        notifyToggle = new ToolStripMenuItem("알림", null, (_, _) => ToggleNotify())
        {
            Checked = notify,
            CheckOnClick = false,
        };
        sourceItem = new ToolStripMenuItem("") { Enabled = false, Visible = false };
        status = new ToolStripMenuItem(lastStatus) { Enabled = false };
        save = new ToolStripMenuItem("저장…", null, (_, _) => SaveLast()) { Enabled = false };
        menu.Items.Add(toggle);
        menu.Items.Add(notifyToggle);
        menu.Items.Add(sourceItem);
        menu.Items.Add(status);
        menu.Items.Add(save);
        menu.Items.Add(new ToolStripSeparator());
        menu.Items.Add(new ToolStripMenuItem("종료", null, (_, _) => Application.Exit()));

        tray = new NotifyIcon
        {
            Text = "clipslim",
            Visible = true,
            ContextMenuStrip = menu,
            Icon = Icon.ExtractAssociatedIcon(Application.ExecutablePath) ?? SystemIcons.Application,
        };
        ApplyOnState();
    }

    protected override void OnHandleCreated(EventArgs e)
    {
        base.OnHandleCreated(e);
        Native.AddClipboardFormatListener(Handle);
    }

    protected override void OnHandleDestroyed(EventArgs e)
    {
        Native.RemoveClipboardFormatListener(Handle);
        base.OnHandleDestroyed(e);
    }

    protected override void SetVisibleCore(bool value)
    {
        if (!IsHandleCreated) CreateHandle();
        base.SetVisibleCore(false);
    }

    protected override void WndProc(ref Message m)
    {
        if (m.Msg == Native.WmClipboardUpdate) Tick();
        base.WndProc(ref m);
    }

    void Tick()
    {
        if (!on || converting) return;
        try
        {
            if (Clipboard.ContainsFileDropList())
            {
                var files = Clipboard.GetFileDropList();
                if (files.Count > 1) return;
                if (files.Count == 1)
                {
                    var path = files[0];
                    if (string.IsNullOrEmpty(path)) return;
                    if (string.Equals(path, lastFile, StringComparison.OrdinalIgnoreCase)) return;
                    var ext = Path.GetExtension(path).TrimStart('.').ToLowerInvariant();
                    if (ext is "gif" or "pdf") return;
                    if (Convert.IsOurs(path)) return;
                    if (ext == "webp") return;
                    if (ext is "png" or "jpg" or "jpeg" or "tif" or "tiff" or "bmp" or "heic" or "heif" or "avif")
                    {
                        Start(path, null, new FileInfo(path).Length, Path.GetFileName(path));
                        return;
                    }
                }
            }
            if (Clipboard.ContainsImage())
            {
                using var bmp = Clipboard.GetImage();
                if (bmp is null) return;
                using var ms = new MemoryStream();
                bmp.Save(ms, ImageFormat.Png);
                Start(null, ms.ToArray(), ms.Length, null);
            }
        }
        catch (ExternalException)
        {
            // clipboard locked by another process
        }
    }

    void Start(string? path, byte[]? bytes, long original, string? sourceName)
    {
        converting = true;
        Task.Run(() =>
        {
            try
            {
                var data = path is not null ? Convert.EncodeFile(path) : Convert.Encode(bytes!);
                BeginInvoke((MethodInvoker)(() => Finish(data, original, sourceName, path, bytes)));
            }
            catch (Exception ex)
            {
                BeginInvoke((MethodInvoker)(() => Fail("실패: " + ex.Message)));
            }
        });
    }

    void Finish(byte[] data, long original, string? sourceName, string? origPath, byte[]? origBytes)
    {
        try
        {
            var url = Convert.WriteTemp(data);
            var files = new StringCollection { url };

            // ponytail: set both file-drop and bitmap; use original source (not re-decoded WebP) for speed
            var bmp = origPath is not null ? new Bitmap(origPath) : new Bitmap(new MemoryStream(origBytes!));
            var obj = new DataObject();
            obj.SetFileDropList(files);
            obj.SetImage(bmp);
            Clipboard.SetDataObject(obj, true);
            bmp.Dispose();

            lastFile = url;
            sourceItem.Text = sourceName ?? "";
            sourceItem.Visible = sourceName is not null;
            var saved = original > 0 ? 1 - data.Length / (double)original : 0;
            var delta = saved > 0 ? $" (−{(int)Math.Round(saved * 100)}%)" : "";
            lastStatus = $"{Convert.Bytes(original)} → {Convert.Bytes(data.Length)} WebP{delta}";
            Rebuild();
            if (notify)
                tray.ShowBalloonTip(2400, sourceName ?? "clipslim", lastStatus, ToolTipIcon.None);
        }
        catch (Exception ex)
        {
            Fail("실패: " + ex.Message);
        }
        finally
        {
            converting = false;
        }
    }

    void Fail(string message)
    {
        converting = false;
        lastStatus = message;
        Rebuild();
        if (notify)
            tray.ShowBalloonTip(2400, "clipslim", message, ToolTipIcon.Error);
    }

    void Toggle()
    {
        on = !on;
        SaveOn();
        ApplyOnState();
    }

    void ToggleNotify()
    {
        notify = !notify;
        SaveNotify();
        notifyToggle.Checked = notify;
    }

    void ApplyOnState()
    {
        toggle.Checked = on;
        tray.Text = on ? "clipslim" : "clipslim (끔)";
        Rebuild();
    }

    void Rebuild()
    {
        status.Text = lastStatus;
        save.Enabled = lastFile is not null && File.Exists(lastFile);
    }

    void SaveLast()
    {
        if (lastFile is null || !File.Exists(lastFile))
        {
            Fail("실패: 저장할 파일이 없습니다");
            lastFile = null;
            Rebuild();
            return;
        }
        using var dialog = new SaveFileDialog
        {
            Filter = "WebP|*.webp",
            FileName = Path.GetFileName(lastFile),
            DefaultExt = "webp",
            InitialDirectory = Environment.GetFolderPath(Environment.SpecialFolder.MyDocuments),
        };
        if (dialog.ShowDialog() != DialogResult.OK) return;
        if (string.Equals(dialog.FileName, lastFile, StringComparison.OrdinalIgnoreCase)) return;
        File.Copy(lastFile, dialog.FileName, overwrite: true);
        tray.ShowBalloonTip(2400, "clipslim", "저장 " + Path.GetFileName(dialog.FileName), ToolTipIcon.None);
    }

    static string OnPath() => Path.Combine(Convert.CacheDir(), "on");
    static string NotifyPath() => Path.Combine(Convert.CacheDir(), "notify");

    bool LoadOn()
    {
        try
        {
            var p = OnPath();
            if (!File.Exists(p)) return true;
            return File.ReadAllText(p).Trim() != "0";
        }
        catch
        {
            return true;
        }
    }

    void SaveOn()
    {
        try { File.WriteAllText(OnPath(), on ? "1" : "0"); } catch { }
    }

    bool LoadNotify()
    {
        try
        {
            var p = NotifyPath();
            if (!File.Exists(p)) return true;
            return File.ReadAllText(p).Trim() != "0";
        }
        catch { return true; }
    }

    void SaveNotify()
    {
        try { File.WriteAllText(NotifyPath(), notify ? "1" : "0"); } catch { }
    }

    protected override void Dispose(bool disposing)
    {
        if (disposing)
        {
            tray.Visible = false;
            tray.Dispose();
            menu.Dispose();
        }
        base.Dispose(disposing);
    }
}

static class Program
{
    [STAThread]
    static int Main(string[] args)
    {
        if (args.Length >= 3 && args[0] == "--convert")
        {
            Native.AttachConsole(Native.AttachParentProcess);
            return Convert.Cli(args[1], args[2]);
        }

        var console = Native.GetConsoleWindow();
        if (console != IntPtr.Zero) Native.ShowWindow(console, Native.SwHide);

        ApplicationConfiguration.Initialize();
        Application.Run(new App());
        return 0;
    }
}
