import { addEntry, clearFeed } from "./../render.js";
import { requestHistory } from "./feed-history.js";

export async function loadHistoryIntoFeed(): Promise<void> {
  try {
    const entries = await requestHistory();
    clearFeed();
    for (const entry of entries) {
      addEntry(
        { name: entry.inst, host: "", port: 0 },
        entry.eventType,
        entry.data,
        { isReplay: true },
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
