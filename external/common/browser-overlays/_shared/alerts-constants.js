const OVERLAY_CONFIG = {
  WS_HOST: "127.0.0.1",
  WS_PORT: 52001, // fallback only — see note above
  WS_ENDPOINT: "/",

  ALERT_DISPLAY_MS: 7000,

  TTS_VOLUME: 0.8,
  TTS_RATE: 1.0,

  SOUND_VOLUME: 1.0, // 0.0 - 1.0

  LOCK_TIMEOUT_MS: 15 * 1000, // auto-release the cross-overlay lock if stuck

  REPO_ROOT: "../../../../../",
  SOUND_FILES: {
    common: {
      // these resolve relative to whichever overlay file calls
      // createAlertOverlay() hence "../../".
      error: "../../_shared/error_alert.mp3",
      unknown: "../../_shared/unknown_alert.mp3",
    },
  },
};
