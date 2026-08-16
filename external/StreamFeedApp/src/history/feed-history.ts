export interface FeedHistoryEntry {
  inst: string;
  eventType: string;
  data: unknown;
  timestamp: string;
}

export function sendHistoryEntry(entry: FeedHistoryEntry): void {
  if (!window.chrome?.webview) return;
  window.chrome.webview.postMessage(
    JSON.stringify({
      type: "historyEntry",
      payload: entry,
    }),
  );
}

export function requestHistory(): Promise<FeedHistoryEntry[]> {
  return new Promise((resolve, reject) => {
    if (!window.chrome?.webview) {
      reject(new Error("WebView2 bridge not available"));
      return;
    }

    const handleResponse = (event: { data: any }) => {
      const parsed = event.data;
      if (parsed.type !== "historyResponse") return;

      window.chrome!.webview!.removeEventListener("message", handleResponse);
      resolve(parsed.payload as FeedHistoryEntry[]);
    };

    window.chrome.webview.addEventListener("message", handleResponse);

    window.chrome.webview.postMessage(
      JSON.stringify({ type: "requestHistory" }),
    );
  });
}
