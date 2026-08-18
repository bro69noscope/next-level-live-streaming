import { addEntry, clearFeed } from "./render.js";

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

export async function loadHistoryIntoFeed(): Promise<void> {
  try {
    const entries = await requestHistory();
    clearFeed();
    for (const entry of entries) {
      addEntry(
        { name: entry.inst, host: "", port: 0 },
        entry.eventType,
        entry.data,
        { isReplay: true, timestamp: entry.timestamp },
      );
    }
  } catch (err) {
    console.error("StreamFeedApp: failed to load history:", err);
  }
}

const loadHistoryBtn = document.getElementById(
  "loadHistoryBtn",
) as HTMLButtonElement;

loadHistoryBtn.onclick = () => {
  loadHistoryIntoFeed();
};
