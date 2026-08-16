import { getConnection } from "./ws-client.js";

const BROADCAST_ACTION_NAME = "replay alert";

export function replayAlert(instanceName: string, payload: unknown): void {
  const ws = getConnection(instanceName);
  if (!ws || ws.readyState !== WebSocket.OPEN) {
    console.error(
      `StreamFeedApp: cannot replay, "${instanceName}" is not connected`,
    );
    return;
  }

  const taggedPayload = { ...(payload as object), isReplay: true };

  ws.send(
    JSON.stringify({
      request: "DoAction",
      action: { name: BROADCAST_ACTION_NAME },
      args: { payloadJson: JSON.stringify(taggedPayload) },
      id: `replay-${Date.now()}`,
    }),
  );
}
