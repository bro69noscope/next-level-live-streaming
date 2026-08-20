(async () => {
  try {
    await loadEnvOverrides();
  } catch (err) {
    log.debug(
      "Aborting overlay init, env setup failed:",
      (err as Error).message,
    );
    return;
  }
  createAlertOverlay({
    name: "twitch",
    subscribedEvents: ["TwitchAlert"],
    kindChance: { follow: 0.0 },
    alerts: [
      {
        kind: "sub",
        sound: "sub_alert.mp3",
        headline: (item) =>
          "just subscribed!" +
          (item.tier && item.tier > 1 ? " (tier " + item.tier + ")" : ""),
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
      {
        // TODO: add a low % funny disproportionate follow alert
        kind: "follow",
        sound: "follow_alert.mp3",
        headline: () => "just followed!",
      },
    ],
  });
})();
