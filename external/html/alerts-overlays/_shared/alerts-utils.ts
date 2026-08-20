function ts(): string {
  return performance.now().toFixed(0) + "ms";
}

function fatalOverlayError(message: string): never {
  log.error("FATAL:", message);
  const banner = document.createElement("div");
  banner.textContent = "OVERLAY ERROR: " + message;
  banner.style.cssText =
    "position:fixed;top:0;left:0;right:0;background:#c00;color:#fff;" +
    "font:bold 20px monospace;padding:8px;z-index:99999;";
  document.body.appendChild(banner);
  throw new Error(message);
}

class Log {
  moduleName: string;

  constructor() {
    const scriptSrc =
      (document.currentScript as HTMLScriptElement | null)?.src || "unknown";
    this.moduleName = (scriptSrc.split("/").pop() ?? scriptSrc).replace(
      ".js",
      "",
    );
  }

  debug(message: unknown, ...args: unknown[]): void {
    if (!(
      window.debug?.[this.moduleName] === true || window.debug?.all === true
    ))
      return;
    console.debug(`[${this.moduleName}] ${ts()} ${message}`, ...args);
  }

  log(message: unknown, ...args: unknown[]): void {
    console.log(`[${this.moduleName}] ${ts()} ${message}`, ...args);
  }

  info(message: unknown, ...args: unknown[]): void {
    console.info(`[${this.moduleName}] ${ts()} ${message}`, ...args);
  }

  warn(message: unknown, ...args: unknown[]): void {
    console.warn(`[${this.moduleName}] ${ts()} ${message}`, ...args);
  }

  error(message: unknown, ...args: unknown[]): void {
    console.error(`[${this.moduleName}] ${ts()} ${message}`, ...args);
  }
}

const log = new Log();
