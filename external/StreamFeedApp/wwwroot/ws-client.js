function connectInstance(inst) {
  const ws = new WebSocket(`ws://${inst.host}:${inst.port}/`);

  ws.onopen = () => {
    state[inst.name] = "connected";
    renderStatus();
    ws.send(
      JSON.stringify({
        request: "Subscribe",
        id: `activity-feed-${inst.name}`,
        events: { Twitch: SUBSCRIBE_EVENTS, General: ["Custom"] },
      }),
    );
  };

  ws.onmessage = (msg) => {
    const parsed = JSON.parse(msg.data);
    if (!parsed.event) return;

    // General.Custom -- fed by CPH.WebsocketBroadcastJson() from a
    // Streamer.bot action. Payload arrives directly as parsed.data.
    if (parsed.event.source === "General" && parsed.event.type === "Custom") {
      if (parsed.data?.clearStreamFeed === true) {
        feedEl.innerHTML = "";
        return;
      }
      if (parsed.data?.event === "KofiAlert") {
        addEntry(inst, `Kofi.${parsed.data.kind}`, parsed.data);
        return;
      }
      return;
    }

    if (parsed.event.source !== "Twitch") return;
    const eventType = parsed.event.type;
    if (!SUBSCRIBE_EVENTS.includes(eventType)) return;
    addEntry(inst, `Twitch.${eventType}`, parsed.data || {});
  };

  ws.onclose = () => {
    state[inst.name] = "disconnected";
    renderStatus();
    setTimeout(() => connectInstance(inst), 2000);
  };
  ws.onerror = () => ws.close();
}
