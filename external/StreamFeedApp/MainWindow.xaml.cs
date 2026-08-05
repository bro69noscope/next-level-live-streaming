using System;
using System.IO;
using System.Windows;
using System.Windows.Input;
using Microsoft.Web.WebView2.Core;

namespace StreamFeedApp
{
    public partial class MainWindow : Window
    {
        public MainWindow()
        {
            InitializeComponent();
            Loaded += MainWindow_Loaded;
        }

        private async void MainWindow_Loaded(object sender, RoutedEventArgs e)
        {
            var userDataFolder = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                "StreamFeedApp",
                "WebView2"
            );

            var env = await CoreWebView2Environment.CreateAsync(userDataFolder: userDataFolder);
            await WebView.EnsureCoreWebView2Async(env);

            WebView.CoreWebView2.WebMessageReceived += WebView_WebMessageReceived;
            WebView.PreviewKeyDown += WebView_PreviewKeyDown;

            var wwwroot = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "wwwroot");
            WebView.CoreWebView2.SetVirtualHostNameToFolderMapping(
                "appassets.local",
                wwwroot,
                CoreWebView2HostResourceAccessKind.Allow
            );
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
            else if (e.Key == Key.X && Keyboard.Modifiers == mods)
            {
                e.Handled = true;
                WebView.CoreWebView2.ExecuteScriptAsync(
                    "document.getElementById('feed').innerHTML = '';"
                );
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
        }

        private void WebView_WebMessageReceived(
            object? sender,
            CoreWebView2WebMessageReceivedEventArgs e
        )
        {
            try
            {
                var json = e.TryGetWebMessageAsString();
                var logDir = Path.Combine(
                    AppDomain.CurrentDomain.BaseDirectory,
                    "..",
                    "..",
                    "..",
                    "logs"
                );
                Directory.CreateDirectory(logDir);
                var logPath = Path.Combine(logDir, "unverified-events.log");
                File.AppendAllText(logPath, $"{DateTime.Now:O}\t{json}{Environment.NewLine}");
            }
            catch
            {
                // logging failure shouldn't crash the app
            }
        }
    }
}
