export function ts(): string {
  const totalMs = performance.now();
  const hours = Math.floor(totalMs / 3600000);
  const minutes = Math.floor((totalMs % 3600000) / 60000);
  const seconds = Math.floor((totalMs % 60000) / 1000);
  const millis = totalMs % 1000;

  const pad = (n: number, len = 2) => String(n).padStart(len, "0");
  return `${pad(hours)}:${pad(minutes)}:${pad(seconds)}.${millis.toFixed(3).padStart(7, "0")}`;
}

export function fatalOverlayError(message: string): never {
  log.error("FATAL:", message);
  const banner = document.createElement("div");
  banner.textContent = "OVERLAY ERROR: " + message;
  banner.style.cssText =
    "position:fixed;top:0;left:0;right:0;background:#c00;color:#fff;" +
    "font:bold 20px monospace;padding:8px;z-index:99999;";
  document.body.appendChild(banner);
  throw new Error(message);
}

export class Log {
  private getCallerModule(): string {
    const stack = new Error().stack;
    if (!stack) return "unknown";
    const lines = stack.split("\n");
    for (const line of lines) {
      const match = line.match(/([\w.-]+)\.js:\d+:\d+/);
      if (match && match[1] !== "alerts-utils") {
        return match[1];
      }
    }
    return "unknown";
  }

  private shouldDebug(moduleName: string): boolean {
    return window.debug?.[moduleName] === true || window.debug?.all === true;
  }

  debug(message: unknown, ...args: unknown[]): void {
    const mod = this.getCallerModule();
    if (!this.shouldDebug(mod)) return;
    console.debug(`[${mod}] ${ts()} ${message}`, ...args);
  }

  log(message: unknown, ...args: unknown[]): void {
    const mod = this.getCallerModule();
    console.log(`[${mod}] ${ts()} ${message}`, ...args);
  }

  info(message: unknown, ...args: unknown[]): void {
    const mod = this.getCallerModule();
    console.info(`[${mod}] ${ts()} ${message}`, ...args);
  }

  warn(message: unknown, ...args: unknown[]): void {
    const mod = this.getCallerModule();
    console.warn(`[${mod}] ${ts()} ${message}`, ...args);
  }

  error(message: unknown, ...args: unknown[]): void {
    const mod = this.getCallerModule();
    console.error(`[${mod}] ${ts()} ${message}`, ...args);
  }
}

export const log = new Log();
