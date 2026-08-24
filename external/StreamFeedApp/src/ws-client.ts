import {
  StreamerbotInstance,
  BUILTIN_STREAMERBOT_TWITCH_EVENTS,
} from "./config.js";
import { state, renderStatus, clearFeed, addEntry } from "./render.js";

const connections: Record<string, WebSocket> = {};

export function getConnection(instanceName: string): WebSocket | undefined {
  return connections[instanceName];
}

export function connectStreamerbotInstance(inst: StreamerbotInstance): void {
  const ws = new WebSocket(`ws://${inst.host}:${inst.port}/`);
  connections[inst.name] = ws;
  ws.onopen = () => {
    state[inst.name] = "connected";
    renderStatus();
    ws.send(
      JSON.stringify({
        request: "Subscribe",
        id: `activity-feed-${inst.name}`,
        events: {
          Twitch: BUILTIN_STREAMERBOT_TWITCH_EVENTS,
          General: ["Custom"],
        },
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
        clearFeed();
        return;
      }

      if (parsed.data?.event === "KofiAlert") {
        addEntry(inst, `Kofi.${parsed.data.kind}`, parsed.data, {
          isReplayEcho: !!parsed.data.isReplay,
        });
        return;
      }

      if (parsed.data?.event === "TwitchAlert") {
        addEntry(inst, `Twitch.${parsed.data.kind}`, parsed.data, {
          isReplayEcho: !!parsed.data.isReplay,
        });
        return;
      }

      return;
    }

    // only for source of truth documentation purposes
    if (parsed.event.source !== "Twitch") return;
    const eventType = parsed.event.type;
    if (!BUILTIN_STREAMERBOT_TWITCH_EVENTS.includes(eventType)) return;

    console.debug(
      `[${inst.name}] native Twitch.${eventType} (logged only):`,
      parsed.data,
    );
  };

  ws.onclose = () => {
    state[inst.name] = "disconnected";
    delete connections[inst.name];
    renderStatus();
    setTimeout(() => connectStreamerbotInstance(inst), 2000);
  };
  ws.onerror = () => ws.close();
}
