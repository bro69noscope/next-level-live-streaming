declare function loadScript(src: string): Promise<void>;

type PortLookupResult<T> =
  { value: T; error: null } | { value: null; error: string };

declare function getPortConfigValue(
  repoRoot: string,
  path: string,
): Promise<PortLookupResult<unknown>>;

interface Window {
  chrome?: {
    webview?: {
      postMessage: (message: string) => void;
    };
  };
}
