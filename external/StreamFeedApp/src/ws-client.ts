import { StreamerbotInstance, TWITCH_STREAMERBOT_EVENTS } from "./config.js";
import { state, renderStatus, feedEl, addEntry } from "./render.js";

export function connectStreamerbotInstance(inst: StreamerbotInstance): void {
  const ws = new WebSocket(`ws://${inst.host}:${inst.port}/`);
  ws.onopen = () => {
    state[inst.name] = "connected";
    renderStatus();
    ws.send(
      JSON.stringify({
        request: "Subscribe",
        id: `activity-feed-${inst.name}`,
        events: { Twitch: TWITCH_STREAMERBOT_EVENTS, General: ["Custom"] },
      }),
    );
  };

  ws.onmessage = (msg) => {
    const parsed = JSON.parse(msg.data);
    console.debug(`[${inst.name}] raw message:`, parsed);
    if (!parsed.event) return;

    // General.Custom: CPH.WebsocketBroadcastJson() from Streamer.bot
    // https://docs.streamer.bot/api/csharp/methods/core/websocket/broadcast-json
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
    if (!TWITCH_STREAMERBOT_EVENTS.includes(eventType)) return;
    addEntry(inst, `Twitch.${eventType}`, parsed.data || {});
  };

  ws.onclose = () => {
    state[inst.name] = "disconnected";
    renderStatus();
    setTimeout(() => connectStreamerbotInstance(inst), 2000);
  };
  ws.onerror = () => ws.close();
}
