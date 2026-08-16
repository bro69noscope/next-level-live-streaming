(async () => {
  try {
    await loadEnvOverrides();
  } catch (err) {
    log.debug("Aborting overlay init, env setup failed:", err.message);
    return;
  }

  createAlertOverlay({
    name: "kofi",
    subscribedEvents: ["KofiAlert"],
    alerts: [
      {
        kind: "kofitip",
        sound: "tip_alert.mp3",
        headline: (item) =>
          "tipped " + (item.amount || "?") + " " + (item.currency || "") + "!",
      },
      {
        kind: "kofisub",
        sound: "kofi_sub_alert.mp3",
        headline: (item) =>
          "subscribed via Ko-fi for " +
          (item.amount || "?") +
          " " +
          (item.currency || "") +
          "!",
      },
      {
        kind: "kofiresub",
        sound: "kofi_resub_alert.mp3",
        headline: (item) =>
          "renewed their Ko-fi membership for " +
          (item.amount || "?") +
          " " +
          (item.currency || "") +
          "!",
      },
    ],
  });
})();
