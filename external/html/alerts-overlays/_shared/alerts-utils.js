function ts() {
  return performance.now().toFixed(0) + "ms";
}

function fatalOverlayError(message) {
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
  constructor() {
    const scriptSrc = document.currentScript?.src || "unknown";
    this.moduleName = scriptSrc.split("/").pop().replace(".js", "");
  }

  debug(message, ...args) {
    if (!(
      window.debug?.[this.moduleName] === true || window.debug?.all === true
    ))
      return;
    console.debug(`[${this.moduleName}] ${ts()} ${message}`, ...args);
  }

  log(message, ...args) {
    console.log(`[${this.moduleName}] ${ts()} ${message}`, ...args);
  }

  info(message, ...args) {
    console.info(`[${this.moduleName}] ${ts()} ${message}`, ...args);
  }

  warn(message, ...args) {
    console.warn(`[${this.moduleName}] ${ts()} ${message}`, ...args);
  }

  error(message, ...args) {
    console.error(`[${this.moduleName}] ${ts()} ${message}`, ...args);
  }
}

log = new Log();
