import type { clearFeed } from "../render.js";
import type { loadHistoryIntoFeed } from "../history.js";

declare global {
  interface Window {
    chrome?: {
      webview?: {
        postMessage: (message: string) => void;
        addEventListener: (
          type: "message",
          listener: (event: { data: any }) => void,
        ) => void;
        removeEventListener: (
          type: "message",
          listener: (event: { data: any }) => void,
        ) => void;
      };
    };
    clearFeed: typeof clearFeed;
    loadHistoryIntoFeed: typeof loadHistoryIntoFeed;
  }
}
