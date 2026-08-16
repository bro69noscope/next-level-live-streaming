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
}
