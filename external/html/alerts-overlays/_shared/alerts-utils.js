function ts() {
  return performance.now().toFixed(0) + "ms";
}

function fatalOverlayError(message) {
  console.error("[alerts-overlay] FATAL:", message);
  const banner = document.createElement("div");
  banner.textContent = "OVERLAY ERROR: " + message;
  banner.style.cssText =
    "position:fixed;top:0;left:0;right:0;background:#c00;color:#fff;" +
    "font:bold 20px monospace;padding:8px;z-index:99999;";
  document.body.appendChild(banner);
  throw new Error(message); // halts remaining execution in this script/callback
}
