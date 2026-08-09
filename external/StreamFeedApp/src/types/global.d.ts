interface Window {
  chrome?: {
    webview?: {
      postMessage: (message: string) => void;
    };
  };
}
