const OVERLAY_CONFIG = {
  WS_HOST: "127.0.0.1",
  WS_PORT: null,
  WS_ENDPOINT: "/",
  ALERT_BASE_DISPLAY_MS: 7000, // non-TTS part of the alert
  TTS_VOLUME: 0.8,
  TTS_RATE: 1.0,
  SOUND_VOLUME: 1.0,
  LOCK_TIMEOUT_MS: 15 * 1000,
  SOUND_RETRY_MAX: 5,
  SOUND_RETRY_DELAY_MS: 500,
  SOUND_CHECK_TIMEOUT_MS: 300,
  SKIP_SILENCE_MS: 5000,
  REPO_ROOT: "../../../../../",
  SOUND_FILES: {
    common: {
      error: "../../_shared/error_alert.mp3",
      unknown: "../../_shared/unknown_alert.mp3",
    },
  },
};
