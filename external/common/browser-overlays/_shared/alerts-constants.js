// TODO: WS_PORT is hardcoded for now — plan is to source it from
// ports.json5 (the same source of truth the OBS/StreamDeck/Streamer.bot
// VCS templaters use) via a small JS reader, instead of duplicating it here.

const OVERLAY_CONFIG = {
  WS_HOST: "127.0.0.1",
  WS_PORT: 52001,
  WS_ENDPOINT: "/",

  ALERT_DISPLAY_MS: 7000,

  TTS_VOLUME: 0.8,
  TTS_RATE: 1.0,

  SOUND_VOLUME: 1.0, // 0.0 - 1.0

  SOUND_FILES: {
    common: {
      error: "error_alert.mp3",
      unknown: "unknown_alert.mp3",
    },
  },
};
