(async () => {
  try {
    await loadEnvOverrides();
  } catch {
    return; // fatalOverlayError already ran
  }
  createAlertOverlay({
    name: "twitch",
    subscribedEvents: ["TwitchAlert"],
    alerts: [
      {
        kind: "sub",
        sound: "sub_alert.mp3",
        headline: () => "just subscribed!",
      },
      {
        kind: "resub",
        sound: "resub_alert.mp3",
        headline: (item) =>
          "resubscribed for " + (item.months || "?") + " months!",
      },
      {
        kind: "giftsub",
        sound: "giftsub_alert.mp3",
        headline: (item) =>
          "gifted a sub to " + (item.recipient || "someone") + "!",
      },
      {
        kind: "giftbomb",
        sound: "giftsub_alert.mp3",
        headline: (item) =>
          "gifted " +
          (item.giftCount || "?") +
          " subs to a buncha wild animals!",
      },
    ],
  });
})();
