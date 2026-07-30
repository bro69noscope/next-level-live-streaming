const OVERLAY_CONFIG = {
  WS_HOST: "127.0.0.1",
  WS_PORT: null,
  WS_ENDPOINT: "/",
  ALERT_DISPLAY_MS: 7000,
  TTS_VOLUME: 0.8,
  TTS_RATE: 1.0,
  SOUND_VOLUME: 1.0,
  LOCK_TIMEOUT_MS: 15 * 1000,
  SOUND_RETRY_MAX: 5,
  SOUND_RETRY_DELAY_MS: 1000,
  REPO_ROOT: "../../../../../",
  SOUND_FILES: {
    common: {
      error: "../../_shared/error_alert.mp3",
      unknown: "../../_shared/unknown_alert.mp3",
    },
  },
};

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
