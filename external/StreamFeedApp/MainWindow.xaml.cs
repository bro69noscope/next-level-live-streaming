using System.IO;
using System.Text.Json;
using System.Windows;
using System.Windows.Input;
using Microsoft.Web.WebView2.Core;

namespace StreamFeedApp
{
    public partial class MainWindow : Window
    {
        private const string AppName = "StreamFeedApp";
        private string _repoRoot = "";
        private string _logDir = "";
        private string _historyPath = "";

        private const int MaxHistoryBytes = 500 * 1024;

        public MainWindow()
        {
            InitializeComponent();
            Loaded += MainWindow_Loaded;
        }

        private static string FindRepoRoot(string startDir)
        {
            var dir = new DirectoryInfo(startDir);
            while (dir != null)
            {
                if (File.Exists(Path.Combine(dir.FullName, "pyproject.toml")))
                {
                    return dir.FullName;
                }
                dir = dir.Parent;
            }
            throw new DirectoryNotFoundException(
                "Could not locate repo root (expected pyproject.toml) walking up from " + startDir
            );
        }

        private async void MainWindow_Loaded(object sender, RoutedEventArgs e)
        {
            var userDataFolder = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                AppName,
                "WebView2"
            );

            _repoRoot = FindRepoRoot(AppDomain.CurrentDomain.BaseDirectory);
            _logDir = Path.Combine(_repoRoot, "external", AppName, "logs");
            _historyPath = Path.Combine(_logDir, "feed-history.json");
            var wwwroot = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "wwwroot");

            var env = await CoreWebView2Environment.CreateAsync(userDataFolder: userDataFolder);
            await WebView.EnsureCoreWebView2Async(env);

            WebView.CoreWebView2.SetVirtualHostNameToFolderMapping(
                "appassets.local",
                wwwroot,
                CoreWebView2HostResourceAccessKind.Allow
            );

            WebView.CoreWebView2.SetVirtualHostNameToFolderMapping(
                "repo.local",
                _repoRoot,
                CoreWebView2HostResourceAccessKind.Allow
            );

            WebView.CoreWebView2.WebMessageReceived += WebView_WebMessageReceived;
            WebView.PreviewKeyDown += WebView_PreviewKeyDown;

            WebView.CoreWebView2.Navigate("https://appassets.local/stream-feed.html");

            WebView.Focus();
            Activated += (s, args) => WebView.Focus();
        }

        private void WebView_PreviewKeyDown(object sender, KeyEventArgs e)
        {
            var mods = ModifierKeys.Control | ModifierKeys.Shift;

            if (e.Key == Key.Q && Keyboard.Modifiers == mods)
            {
                e.Handled = true;
                Application.Current.Shutdown();
            }
            else if (e.Key == Key.J && Keyboard.Modifiers == mods)
            {
                e.Handled = true;
                WebView.CoreWebView2.ExecuteScriptAsync(
                    "document.getElementById('toggleRawBtn').click();"
                );
            }
            else if (e.Key == Key.F && Keyboard.Modifiers == mods)
            {
                e.Handled = true;
                WebView.CoreWebView2.ExecuteScriptAsync(
                    "document.getElementById('toggleTwitchFollowsBtn').click();"
                );
            }
            else if (e.Key == Key.X && Keyboard.Modifiers == mods)
            {
                e.Handled = true;
                WebView.CoreWebView2.ExecuteScriptAsync("window.clearFeed();");
            }
            else if (e.Key == Key.H && Keyboard.Modifiers == mods)
            {
                e.Handled = true;
                WebView.CoreWebView2.ExecuteScriptAsync("window.loadHistoryIntoFeed();");
            }
        }

        private void WebView_WebMessageReceived(
            object? sender,
            CoreWebView2WebMessageReceivedEventArgs e
        )
        {
            try
            {
                var json = e.TryGetWebMessageAsString();
                using var doc = JsonDocument.Parse(json);
                var root = doc.RootElement;
                var messageType = root.GetProperty("type").GetString();

                switch (messageType)
                {
                    case "unverifiedEvent":
                        HandleUnverifiedEvent(root.GetProperty("payload"));
                        break;

                    case "historyEntry":
                        HandleHistoryEntry(root.GetProperty("payload"));
                        break;

                    case "requestHistory":
                        HandleRequestHistory();
                        break;

                    default:
                        break;
                }
            }
            catch
            {
                // logging/parsing failure shouldn't crash the app
            }
        }

        private void HandleUnverifiedEvent(JsonElement payload)
        {
            Directory.CreateDirectory(_logDir);
            var logPath = Path.Combine(_logDir, "unverified-events.log");
            var payloadJson = payload.GetRawText();
            File.AppendAllText(logPath, $"{DateTime.Now:O}\t{payloadJson}{Environment.NewLine}");
        }

        private void HandleRequestHistory()
        {
            string historyJson = "[]";
            if (File.Exists(_historyPath))
            {
                historyJson = File.ReadAllText(_historyPath);
            }

            var response = new
            {
                type = "historyResponse",
                payload = JsonSerializer.Deserialize<JsonElement>(historyJson),
            };

            var responseJson = JsonSerializer.Serialize(response);
            WebView.CoreWebView2.PostWebMessageAsJson(responseJson);
        }

        private void HandleHistoryEntry(JsonElement payload)
        {
            Directory.CreateDirectory(_logDir);

            List<JsonElement> entries = [];
            if (File.Exists(_historyPath))
            {
                var existingJson = File.ReadAllText(_historyPath);
                using var existingDoc = JsonDocument.Parse(existingJson);
                entries = [.. existingDoc.RootElement.EnumerateArray().Select(el => el.Clone())];
            }

            entries.Add(payload.Clone());

            while (TotalBytes(entries) > MaxHistoryBytes && entries.Count > 0)
            {
                entries.RemoveAt(0);
            }

            var serialized = JsonSerializer.Serialize(entries);
            File.WriteAllText(_historyPath, serialized);
        }

        private static int TotalBytes(List<JsonElement> entries)
        {
            int total = 0;
            foreach (var entry in entries)
            {
                total += System.Text.Encoding.UTF8.GetByteCount(entry.GetRawText());
            }
            return total;
        }
    }
}
