export {};

declare global {
  interface Window {
    debug: Record<string, boolean>;
    skipCurrentAlert?: () => void;
  }
}
